# ONEchat — Plan de la página web oficial (propuesta para aprobación)

**Fecha:** 24 de noviembre de 2026 · **Estado:** PROPUESTA —
nada de esto está construido; se monta solo con la
aprobación de Mario.
**Base:** la app ONEchat (v2026.11.24.7, acceso anticipado)
y su mismo backend. La web no duplica datos: lee y escribe
en la misma plataforma.

## 1. La idea en una frase

Un sitio oficial que es la **casa pública** de ONEchat: la
portada presenta la marca (el logo nuevo), permite **entrar
al chat directo desde la página principal**, y muestra la
**comunidad** — el directorio de usuarios registrados y las
**páginas personales con galería de fotos** vinculadas al perfil
del chat — con un **foro** como espacio de conversación con
memoria.

Por qué suma: el chat es efímero y cerrado (hay que estar
dentro); la web es **descubrible** (Google, enlaces que se
comparten, páginas de usuario que circulan). Cada página personal
compartido es publicidad gratuita que trae gente al chat.

## 2. Mapa del sitio propuesto

- **Inicio (portada):** cabecera con el logo oficial sobre
  su degradado; eslogan; botón grande **«Entrar al chat»**
  (y la opción de abrir el chat embebido a pantalla
  completa); franja viva con «ahora en línea» y salas
  activas (datos reales de presencia); tarjetas de usuarios
  destacados/nuevos de la comunidad; acceso a Comunidad,
  Foro y Premium.
- **Chat:** la app actual, a pantalla completa, en su
  propia ruta. Desde la portada se llega en un toque; quien
  ya tiene sesión entra directo a la Sala General, como hoy.
- **Comunidad:** directorio público de usuarios
  **registrados** (los invitados no aparecen): tarjeta con
  foto, nickname con su color, país, bio breve y estado
  (en línea / última vez). Buscador por nickname y filtro
  por país. Orden sugerido: en línea primero, luego más
  activos, luego más nuevos.
- **Página personal con su Galería — /u/Nickname:** la página de
  cada usuario registrado: foto principal, bio, país,
  insignias del chat, su **galería de fotos** y botones
  «Enviar mensaje» / «Ver en el chat» que abren la app en su
  conversación. Vinculación en los dos sentidos: la ficha
  del usuario **dentro de la app** tendrá «Ver su página» y
  la web enlaza de vuelta al chat.
  - **Límite gratuito: 3 fotos** por usuario.
  - **Premium: fotos ilimitadas** (y portada destacada).
  - El usuario controla su página: puede ocultarla del
    directorio (interruptor en su Perfil de la app).
- **Foro:** categorías iniciales — Anuncios oficiales (solo
  Staff publica), Presentaciones, Ayuda y soporte,
  Sugerencias, Off-topic. Se entra **con la misma cuenta
  del chat** (mismo nickname y avatar); los mismos roles
  moderan (Staff global; el dueño puede fijar y cerrar
  temas). Aviso en la app cuando hay respuestas a tus temas
  (una notificación más en Status).
- **Premium (vitrina):** qué incluye la membresía — fotos
  ilimitadas en la Galería, «Cine juntos», insignia Premium
  y lo que definamos en la Etapa 6 — con captación de
  interés («Avísame cuando abra»). Sin cobros todavía: el
  sistema de pago es parte de la Etapa 6 y requiere las
  decisiones de esa etapa.
- **Ayuda y normas:** FAQ (cómo registrarse, cómo funciona
  el chat) y las normas de la comunidad (las mismas reglas
  que rigen la moderación dentro de la app).

## 3. Diseño

- **Identidad:** el logo nuevo manda — degradado
  celeste/lila + blanco en las cabeceras del sitio, y el
  turquesa oficial (#00C2A8) como color de acción (botones
  «Entrar al chat», enlaces, estados en línea). La app
  mantiene su tema oscuro: el contraste es deliberado —
  la web es la vitrina luminosa; el chat, el interior.
- **La Galería como protagonista visual:** tarjetas grandes
  con foto, rejilla de galería limpia, página personal con
  cabecera amplia — el espíritu de la página personal (perfil que se
  visita y se comparte) actualizado a estándar moderno.
- **Móvil primero:** la mayoría llegará por el teléfono y
  por enlaces compartidos; el sitio se diseña primero para
  pantalla chica y se adapta a escritorio.
- **Velocidad:** sitio liviano (estático + datos en vivo
  mínimos) para que abra rápido incluso con conexiones
  lentas; las fotos se sirven en tamaños optimizados.
- **Idioma:** ES primero, con la misma base de textos que
  la app para sumar EN sin rehacer.

## 4. Cómo se monta (técnica, sin duplicar nada)

- **Mismo backend:** la web usa el mismo proyecto Supabase.
  Lo público se expone con reglas estrictas: solo perfiles
  marcados como públicos y sus fotos; **jamás** correos,
  contraseñas, privados, susurros ni datos de moderación.
- **Fotos:** Supabase Storage — cada usuario sube solo a su
  propia carpeta (regla del servidor); el límite de 3 /
  ilimitado se controla contando en el servidor con el
  indicador Premium del perfil (el mismo que usará la
  Etapa 6). Tamaño máximo por foto y formatos estándar,
  con miniaturas automáticas.
- **Foro:** tablas nuevas del mismo proyecto (categorías,
  temas, respuestas) con las mismas garantías: publicar
  exige sesión; moderar exige rol; todo queda registrado.
- **Dónde vive:** al inicio, en el mismo GitHub Pages
  (gratis), como sitio hermano de la app. Cuando Mario
  apruebe un **dominio propio**, el sitio y la app se mudan
  a él (p. ej. la portada en el dominio raíz y el chat en
  /chat o chat.dominio) sin rehacer nada.
- **Vínculo app ↔ web:** enlaces profundos — la ficha del
  usuario en la app abre su página con su Galería; la página abre la app
  en la conversación con esa persona (si no tiene cuenta,
  lo invita a registrarse con ese nickname de destino ya
  abierto al entrar).

## 5. Fases de montaje (cada una se aprueba por separado)

- **Fase W1 — Portada + Chat directo + Comunidad:**
  portada con el logo, botón/embebido del chat, franja de
  presencia y el directorio de registrados con buscador.
  Es la cara pública mínima y ya enlaza todo lo que existe.
- **Fase W2 — Galería:** páginas /u/Nickname con galería
  (3 fotos gratis), subida de fotos desde el Perfil de la
  app, interruptor de privacidad y el enlace «Ver su
  página» en la ficha del usuario dentro de la app.
- **Fase W3 — Foro:** categorías, temas y respuestas con
  la cuenta del chat, moderación del Staff y aviso en
  Status de la app.
- **Fase W4 — Vitrina Premium + dominio propio:** página
  Premium con captación de interés y, con la aprobación del
  gasto, compra y conexión del dominio oficial.

## 6. Costos

- Fases W1–W3: **US$0** sobre lo que ya existe (GitHub
  Pages + Supabase actual). Las fotos usan el
  almacenamiento del proyecto: en el plan Free alcanza
  para el alfa; si la galería crece, es otro motivo para
  el plan Pro (US$25/mes) que ya está previsto evaluar.
- Fase W4: el **dominio** es el único gasto nuevo
  (referencia habitual: ~US$10–20 al año según la
  extensión) y se compra solo con aprobación de Mario.

## 7. Decisiones que necesito de Mario para partir

1. **Alcance de la primera entrega:** ¿partimos con W1
   sola, o con W1 + W2 (portada, comunidad y galería de una
   vez)? Mi recomendación: **W1 + W2** — la galería es la
   gancho que hace compartible al sitio.
2. **Visibilidad del directorio:** ¿toda persona registrada
   aparece por defecto (pudiendo ocultarse), o solo quien
   active «perfil público»? Mi recomendación: **visible por
   defecto con interruptor para ocultarse** — un directorio
   vacío no atrae a nadie, y el control queda en el
   usuario.
3. **Foro:** ¿en la primera etapa o queda para W3 como
   está planteado? Mi recomendación: **W3** — primero la
   comunidad y la galería; el foro rinde cuando ya hay
   comunidad que lo habite.
4. **Dominio:** ¿lo vemos ahora (te traigo opciones de
   nombre y precio verificadas) o el sitio nace en la
   dirección actual de GitHub y el dominio se decide en
   W4? Mi recomendación: **nacer ya y decidir el dominio en
   paralelo**, sin bloquear el lanzamiento.
5. **Fotos de la Galería:** ¿las 3 fotos gratuitas son solo
   galería, o la foto principal de la página cuenta dentro
   de las 3? Mi recomendación: **la principal no cuenta**
   (es el avatar grande de la página); las 3 son de
   galería.

Con esas cinco respuestas (o tu «tal cual» general), el
plan queda aprobado y la Fase W1 parte cuando tú digas.
