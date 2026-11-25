# ONEchat — Estado del acceso anticipado

**Fecha:** 24 de noviembre de 2026 · **App en vivo:**
v2026.11.24.11
**Parte 1:** lo solucionado durante el early (con
verificación). **Parte 2:** lo agendado para implementar.

## Parte 1 — Solucionado durante el early access

### Fallos corregidos (reportados probando en vivo)

1. **Privados invisibles:** las conversaciones nuevas no
   aparecían en la pestaña Privados del receptor. Causa: la
   lista cargaba una sola vez y la pila de pestañas la
   dejaba congelada. Arreglo: recarga al volver a la pestaña
   + suscripción en tiempo real a los privados entrantes.
2. **Status genérico e inerte:** los avisos decían solo
   «Nuevo mensaje privado» y tocarlos no hacía nada. Ahora
   cada aviso dice quién y dónde («X te mencionó en Sala»,
   «X te invitó a jugar al Gato») y al tocarlo navega a la
   conversación o la sala.
3. **Contadores que no se actualizaban en vivo:** las
   alertas de Privados y Status solo cambiaban al cambiar
   de pestaña. Ahora la pantalla principal escucha en vivo
   y los contadores se mueven solos estés donde estés.
4. **Mensajes duplicados del emisor («eco»):** el que
   enviaba veía su mensaje dos veces por una carrera entre
   el envío y el eco en tiempo real. Corregido en los tres
   caminos (sala, susurro y privado). La base nunca tuvo
   duplicados; en el navegador de Mario además pesaba una
   versión vieja en caché — por eso la app muestra ahora su
   versión al final del Perfil.
5. **El invitado al Gato no veía el botón Aceptar:** los
   botones del tema no se pintaban dentro de la tarjeta del
   juego en web. La tarjeta usa ahora botones propios;
   verificado jugando una partida real como invitado.

### Funciones entregadas durante el early

6. **Gato 1 vs 1 en privados** (adelanto de la Etapa 6 a
   pedido de Mario): invitación con tarjeta y aviso en
   Status, tablero en vivo sobre el chat, rendirse y
   revancha; el servidor valida turno, celda y ganador.
   Verificado con 13 controles y partida real.
7. **Logo oficial integrado:** el wordmark de Mario en la
   bienvenida y en la barra superior (tras corregir el
   publicador, que dejó la primera versión sin la imagen).
8. **Registro de IP de conexiones:** cada visita queda
   registrada con la IP observada por el servidor (nadie
   puede falsificarla); solo la ven Staff y dueño, y la
   ficha del usuario muestra su última conexión. Con aviso
   de privacidad en la bienvenida. (El invitado «Mario» del
   24-11 no pudo rastrearse: su visita fue anterior a este
   registro; desde ahora toda visita queda registrada.)
9. **Revisión ortográfica completa** de la app (diccionario
   ES/EN, salas, textos): sin errores; «conveza» no existe
   en el sistema. Corrección aplicada: el título de la
   pestaña web pasó a «ONEchat» con su descripción propia.
10. **Manual de administración v1.0** entregado (PDF):
    cuentas, roles, moderación, operación del alfa,
    publicación, costos y solución de problemas.
11. **El Destierro — Fase S1 antitóxicos** (prioridad de
    Mario): identidad de dispositivo persistente + huella,
    puerta de entrada que verifica en cada visita, y la
    sanción que bloquea cuenta + dispositivo + IP a la vez
    desde la ficha (Staff temporal, permanente solo el
    dueño, con motivo auditado). El desterrado ve la
    pantalla «Acceso revocado» y tampoco puede escribir con
    la sesión abierta. Verificado con 12 controles jugando
    al tóxico (cuenta nueva + mismo dispositivo =
    bloqueada; sin la IP, el dispositivo solo sigue
    bloqueando) y con prueba visual en la app real.

## Parte 2 — Agendado para implementar

### Al cerrar el early (lista post-alfa, en docs/CAMBIOS-POST-ALFA.md)

1. **«Mencionar» en la ficha del usuario** (+ evaluar
   autocompletado al escribir @). El sistema de menciones
   ya funciona; falta hacerlo visible para quien escribe.
2. **Panel del dueño para roles globales** (dar/quitar
   Staff y moderador global desde la app; hoy solo por
   base de datos).
3. **Destacado por moderadores:** verificar que todo
   moderador lo vea y pueda usarlo en sus salas.
4. **Iconos por rango** (designados por Mario): destacado
   = manzana, moderador y dueño de sala = placa de sheriff,
   Staff = ⚔️, dueño del chat = el del moderador por ahora.
5. **El teclado debe empujar la conversación** hacia
   arriba (sugerencia de YouShookMe).
6. **Pantalla siempre encendida** con el chat abierto
   (sugerencia de YouShookMe; en web es limitado).
7. **Fallo: el color de nick propio no se refleja** en la
   Sala General para el propio usuario (los demás sí lo
   ven).
8. **Videos de YouTube dentro de la app:** tarjeta con
   miniatura y reproductor oficial, sin autoplay.
9. **Enlaces de terceros en salas:** el mensaje no se
   publica y el autor queda silenciado con escalera
   creciente (5 min → 30 min → 2 h → 24 h). Sin baneo
   automático: lo decide el Staff con el historial.
10. **Avisos de moderación en Status con alcance por
    rol:** dueños/moderadores de sala solo lo de su sala;
    dueño global y Staff, todo (infracciones, sanciones y
    reportes).
11. **Privacidad de privados por usuario:** abrir/cerrar
    los privados; los favoritos propios siempre pueden
    escribir. Aplicado en el servidor.
12. **Avisos del sistema dentro de la sala:** entradas,
    salidas, silencios y baneos (estos dos sin mostrar el
    nick), con interruptor por usuario.
13. **Cambiar de nick desde el Perfil:** cambio atómico
    en el servidor, conservando cuenta, roles y
    membresías; los mensajes antiguos quedan con el nick
    original. Definir freno anti-abuso.
14. **Desactivar susurros por usuario** (anti-acoso), con
    la misma excepción de favoritos que los privados.
15. **«Copiar» en el menú de toque largo**, junto a
    «Traducir», en salas, susurros y privados.
16. **Sonidos del chat y alerta de mención** (sonido
    distintivo + vibración), con ajustes por usuario.

### Etapas y planes mayores

17. **Etapa 6 (resto): Premium y más juegos** — Conecta 4,
    Damas, Ludo y Ajedrez; y **«Cine juntos»** (película en
    simultáneo 1:1, solo Premium; vía realista: sincronizar
    YouTube).
18. **Web oficial** (plan entregado; diseño elegido por
    Mario: mezcla A + C): W1 portada con chat directo y
    Comunidad, W2 páginas personales con **Galería** de
    fotos (3 gratis, ilimitadas Premium — el término
    «fotolog» quedó eliminado por decisión de Mario), W3
    foro, W4 vitrina Premium y dominio propio. Pendiente:
    la aprobación del plan y sus 5 decisiones de alcance.
19. **Seguridad antitóxicos, fases siguientes:** S2
    anti-evasión (cuentas hermanas visibles en la ficha,
    límite de invitados por dispositivo/IP, bloqueo de
    correos desechables, anti-suplantación de nicks con
    imitaciones visuales) y S3 anti-doxxing (detector de
    datos personales en salas con freno y registro,
    reportes con evidencia automática, exportación de
    evidencia ante amenazas graves).

### Decisiones pendientes de Mario

- **Comentarios de YouShookMe:** el turquesa de los nicks
  no se ve bien y pide más colores de nick (sin decidir).
- **Fotos de perfil:** el tester preguntó si llegan
  «mañana»; sin fecha prometida (se enlaza con la Galería
  de la web oficial, W2).
- **Web oficial:** aprobación del plan y las 5 decisiones
  (alcance inicial, visibilidad del directorio, foro,
  dominio, si la foto principal cuenta en las 3).
- **Etapa 6:** luz verde para partir con Premium y los
  juegos restantes cuando Mario lo indique.
