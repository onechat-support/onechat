# ONEchat — Web oficial W1 + W2 (construida)

**Fecha:** 24 de noviembre de 2026 · **Aprobación de
Mario:** el mismo día («aprobar el plan y construir la
web», diseño mezcla A + C, chat en su lugar definitivo).
**Costo:** US$0 (GitHub Pages + Supabase actual).

## El lugar definitivo

- **Sitio:** https://onechat-support.github.io/
  (repo `onechat-support/onechat-support.github.io`,
  rama main; publicador:
  `custom.github/bin/publish_site.py`).
- **El chat vive en /chat/** (compilado con
  `--base-href /chat/`). La dirección antigua
  (/onechat/) sigue publicándose en paralelo durante el
  alfa; ambas corren la misma versión.
- Un dominio propio sigue siendo decisión de la fase W4.

## W1 — Portada, chat directo y Comunidad

- **Portada** (diseño mezcla A + C): base luminosa con el
  degradado del logo; héroe en dos columnas con el **chat
  oscuro en vivo** embebido (iframe a /chat/) y franja de
  presencia real («en línea ahora» = actividad < 6 min,
  leída del mismo backend con sesión anónima de solo
  lectura); chips de las 30 salas; avance de la Comunidad;
  banda Premium.
- **Comunidad** (`comunidad.html`): directorio de cuentas
  **registradas** con `show_in_directory` activo;
  buscador por nickname y filtro por país; en línea
  primero. Los invitados no aparecen.
- **Páginas personales** `/u/Nickname` (404.html redirige
  a `u.html?nick=`): foto-letra con su color, país, bio,
  estado y su Galería.

## W2 — Galería

- **Migración v1.16:** `profiles.show_in_directory`
  (defecto true) y `profiles.is_premium` (defecto false;
  congelado ante auto-edición como global_role — nadie se
  auto-otorga Premium); tabla `gallery_photos` (lectura
  con sesión, escritura solo del dueño); **gatillo de
  límite: 3 fotos gratis, Premium ilimitadas** (error
  `gallery_limit`); bucket de Storage `gallery` público
  con escritura solo en la carpeta `<uid>/` propia.
- **App v2026.11.24.12:** en el Perfil (solo registrados),
  sección «Mi página web»: interruptor «Aparecer en la
  Comunidad», botón «Ver mi página web», y «Mi Galería»
  (subir foto desde el equipo, miniaturas, borrar; el
  límite muestra el aviso amable). En la ficha de cada
  usuario registrado: botón «Ver su página».
- La foto principal de perfil NO cuenta dentro de las 3
  (decisión recomendada y adoptada): la Galería es aparte.

## Verificación (2026-11-24)

- Sitio y rutas: portada, comunidad, /chat/ y assets con
  HTTP 200; `main.dart.js` en vivo idéntico al compilado
  (MD5) en /chat/ y en /onechat/.
- Datos reales: sesión anónima lee perfiles registrados
  (Zeeth, ZethRegistro) con las columnas nuevas y las 30
  salas.
- Galería de punta a punta con ZethRegistro: subida al
  bucket en su carpeta, 3 filas creadas, **la 4ª rechazada
  con gallery_limit**, limpieza total posterior.

## Decisiones adoptadas (recomendaciones del plan)

Alcance W1 + W2 de una vez; directorio visible por
defecto con interruptor; foro queda en W3; sin dominio
por ahora (W4); la foto principal no cuenta en las 3.
Quedan: **W3 foro** y **W4 vitrina Premium + dominio**,
cuando Mario lo indique.
