# Plan de acción — ONEchat en Google Play

**Fecha:** 2026-11-26 · **Estado:** plan para aprobación de Mario
**Objetivo:** publicar ONEchat (Android) en Google Play, en producción.

## Resumen ejecutivo

La app ya cumple por dentro gran parte de lo que Google Play exige a un chat
con contenido de usuarios. Lo que falta no es la app: es (1) **decidir el tipo
de cuenta de desarrollador**, (2) **cerrar y publicar el paquete legal**,
(3) **adaptar la compilación web a Android nativo** y (4) recorrer el circuito
de pruebas y revisión de Google. La ruta crítica es la decisión de la cuenta:
con cuenta **personal** Google impone una prueba cerrada de **12 testers por
14 días** antes de producción; con cuenta de **organización** (la SpA) esa
prueba no existe, pero se necesita el número DUNS de la empresa.

## Lo que YA está listo (trabajo adelantado)

- **Eliminación de cuenta** dentro de la app y desde la web
  (https://getonechat.com/eliminar-cuenta.html), requisito obligatorio de Play.
- **Moderación y seguridad** que exige la política de contenido generado por
  usuarios (UGC): reportar con evidencia, bloquear usuarios, equipo de
  moderación con código de conducta y Centinel vigilando conversaciones de
  riesgo las 24 horas.
- **Borrador legal v0.1** redactado (Términos, Normas, Seguridad Infantil y
  Privacidad) según las políticas oficiales de Play.
- **Dominio propio** getonechat.com donde se publicarán las páginas legales.
- Correo oficial del proyecto: onechat.support@gmail.com.

## Fase 0 — Decisiones de Mario (ruta crítica)

1. **Tipo de cuenta de desarrollador** (una sola vez, no se puede cambiar
   después sin crear otra cuenta):
   - **Personal** — US$25 (pago único). La ficha muestra su nombre personal.
     Al ser una cuenta nueva, Google exige **prueba cerrada con al menos 12
     testers aceptados durante 14 días continuos** y luego una solicitud de
     acceso a producción con cuestionario (10 preguntas). Los testers deben
     usar la app de verdad; si alguien se sale, el reloj de 14 días se
     reinicia, así que se reclutan 15–20 personas.
   - **Organización (SpA)** — US$25 (pago único). La ficha muestra el nombre
     de la empresa. **No hay prueba de 12 testers.** Requiere el **número
     D-U-N-S** de la empresa (gratis, pero puede tardar días o semanas:
     pedirlo apenas exista la SpA). Depende de la decisión de la empresa en
     Chile, hoy pendiente.
2. **Ley aplicable del documento legal** (recomendación vigente: Nevada como
   ley rectora con cláusula que respeta los derechos irrenunciables de los
   usuarios en Chile; si la operadora es la SpA, se revisa al cerrarla a su
   nombre). Sin esto no se pueden publicar las páginas legales, y la política
   de privacidad publicada es requisito para salir en Play.
3. **Cuenta de Google dueña de Play Console**: recomendado
   onechat.support@gmail.com (la del proyecto, ya conectada con Muse).

## Fase 1 — Preparación técnica Android (Muse)

1. **Identidad de la app**: applicationId definitivo (p. ej.
   com.getonechat.app), nombre «ONEchat», icono adaptativo desde el logo y
   pantalla de arranque.
2. **Nivel de API objetivo 36 (Android 16)**: desde el 31-08-2026 Google solo
   acepta apps nuevas que apunten a API 36 o superior. Se verifica la
   configuración de Flutter y se ajusta si hace falta.
3. **Firma**: activar Play App Signing y generar la llave de subida; la llave
   se resguarda en la bóveda segura (perderla complica la cuenta para
   siempre).
4. **Adaptación de funciones solo-web**: los reproductores de YouTube
   (flotante y «Cine juntos») hoy usan tecnología del navegador; en Android se
   implementan con reproductor nativo (WebView) para que funcionen igual.
   WakeLock pasa a su equivalente nativo. Sonidos y vibración ya están
   preparados por plataforma.
5. **Permisos mínimos**: solo los que la app usa (red, vibración, cámara/
   galería al subir fotos, WakeLock), cada uno con su justificación lista
   para los formularios.
6. **Compilación .aab** (Android App Bundle, el formato que exige Play) y
   prueba en un dispositivo Android real antes de subir nada.

## Fase 2 — Consola y cumplimiento (Muse prepara; Mario aprueba textos)

1. **Crear la cuenta** en Play Console (US$25) y verificar la identidad que
   Google pida (documento y, en organización, DUNS).
2. **Ficha de la tienda**: descripción corta y completa (ES y EN), icono
   512×512, imagen destacada 1024×500 y capturas de pantalla reales.
   La ficha **no** debe promover la sala +18 (política de contenido sexual:
   ONEchat entra como red social con UGC incidental, no como app de
   contenido adulto).
3. **Publicar las páginas legales** en getonechat.com: Política de Privacidad
   (URL pública obligatoria), Términos y Estándares de Seguridad Infantil.
4. **Formulario Data Safety**: declarar con exactitud lo que la app recoge
   (correo, nickname, mensajes, registro de IP, huella de dispositivo,
   fotos de la Galería) y que la eliminación de datos está disponible.
5. **Cuestionario de clasificación de contenido (IARC)** y **audiencia
   objetivo: solo mayores de 18 años** (simplifica todo: sin política de
   familias ni público infantil).
6. **Declaraciones UGC y seguridad infantil**: describir la moderación
   (reportes, bloqueo, equipo humano, Centinel), designar el **contacto de
   seguridad infantil** (onechat.support@gmail.com) y registrar la **URL de
   eliminación de cuenta** ya construida.
7. **Acceso para los revisores de Google**: cuenta de prueba registrada e
   instrucciones de acceso (el ingreso como invitado facilita la revisión).

## Fase 3 — Pruebas

1. **Prueba interna** (inmediata, hasta 100 testers): validar instalación,
   registro, salas, privados, Galería y Cine en Android real.
2. **Prueba cerrada — SOLO si la cuenta es personal**: 12+ testers aceptados
   por 14 días continuos, con uso real; los testers actuales del Early sirven
   si tienen Android. Al cumplir, se envía la **solicitud de acceso a
   producción** (cuestionario sobre la prueba).
   Con cuenta de organización este paso no existe.

## Fase 4 — Revisión y lanzamiento

1. Enviar la versión a **producción** y pasar la **revisión de Google**
   (habitualmente 7 días o menos; la primera revisión de una cuenta nueva
   puede tardar más). Si Google observa algo, se responde y se reenvía.
2. **Despliegue por etapas**: publicar primero a un porcentaje de países/
   usuarios y subir a 100% vigilando errores (Android vitals).

## Fase 5 — Después del lanzamiento

- Vigilar Android vitals (cierres y ANR) y las reseñas.
- Mantener la app al día con el nivel de API que Google exija cada año.
- Premium y pagos llegarán después con facturación de Google Play (requiere
  la empresa para recibir pagos sin fricción).

## Costos

- Play Console: **US$25, pago único**.
- DUNS (solo organización): **gratis**.
- Todo lo demás: US$0. Sin gastos sin aprobación previa de Mario.

## Tiempos estimados (desde la decisión de la Fase 0)

- **Ruta organización**: 1–2 semanas de preparación y revisión, más lo que
  tarde el DUNS si aún no está.
- **Ruta personal**: 4–6 semanas (los 14 días de prueba cerrada son
  calendario fijo e incompresible, más la revisión).

## Fase 6 — Crecimiento por país (estrategia aprobada por Mario, 2026-11-26)

Chatsi publica apps clonadas por país («Chat Chile», etc.) que abren su sala
local. Es técnicamente trivial (mismo código, otro identificador, icono y
sala preseleccionada), pero **viola la política de spam de Google Play**
(contenido repetitivo: varias apps con la misma experiencia) y la sanción
puede alcanzar a toda la cuenta de desarrollador. **Decisión: NO clonar.**

La vía aprobada logra el mismo efecto sin riesgo:

1. **Una sola app** con **fichas de tienda personalizadas por país** en Play
   Console (hasta 50): quien busca desde Chile ve título, descripción y
   capturas enfocados en Chile; desde México, los suyos. Prioridad: Chile,
   México, Argentina, Colombia, Perú y España.
2. La app ya **abre sola la sala del país** según la conexión (en vivo desde
   v2026.11.26.4), así que la experiencia «entro y estoy en mi sala» ya es
   la misma que promete el clon.
3. **Páginas web por país** en getonechat.com (chat-chile, chat-mexico, …)
   con su SEO propio, para capturar la búsqueda en Google y derivar a la app.

Los clones quedan descartados salvo que Mario lo reordene conociendo el
riesgo; si algún día se hicieran, con cuenta personal cada uno exigiría su
propia prueba cerrada de 12 testers por 14 días.

## Riesgos y notas honestas

- La sala «Hot +18» es el punto delicado frente a la política de contenido
  sexual de Play: la app es defendible como red social con moderación, pero
  la ficha y las capturas no deben mostrar ni promover esa sala.
- La primera revisión puede pedir cambios (textos, declaraciones); es
  normal y está contemplado en los tiempos.
- El nombre «ONEchat» en Play se confirma al crear la app en la consola;
  si estuviera tomado, se publica como «ONEchat — Salas de chat» sin cambiar
  el nombre dentro de la app.
