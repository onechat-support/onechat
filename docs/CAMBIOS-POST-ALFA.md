# Cambios para implementar al finalizar el acceso anticipado

Anotados por Mario y por los testers durante el alfa (2026-11-23).
NO implementar hasta que Mario declare cerrado el early access.

> **ACTUALIZACIÓN 2026-11-26 — ORDEN DE MARIO:** integrar TODOS estos
> cambios AHORA, durante el Early, para probarlos con los testers y
> evitar sorpresas al anunciar la Beta. La regla anterior queda
> reemplazada por esta orden. Implementación por lotes (A servidor y
> privacidad, B social y visual, C mensajes y multimedia, D Premium),
> cada lote publicado y verificado en vivo antes de pasar al siguiente.

## Pedidos de Mario (2026-11-23, chat y sala Ayuda)

1. **Opción «Mencionar» en la ficha del usuario.** Al seleccionar
   el nick de otra persona debe existir «Mencionar», que inserte
   `@Nick` en el campo de texto. Diagnóstico: el sistema de
   menciones SÍ funciona (detecta `@nick` al enviar, pinta el
   mensaje en rojo para el mencionado y le crea aviso en Status;
   comprobado en vivo: la mención de Zeeth a PruebaZeth generó su
   notificación), pero el emisor no ve ninguna señal, no hay
   botón ni autocompletado — por eso «no parece funcionar».
   Evaluar además autocompletado al escribir `@`.
2. **Gestión de roles globales desde la cuenta del dueño.** Hoy
   la app solo permite nombrar moderadores DE SALA; dar estatus
   global de Staff o de moderador global (y dueño) no existe en
   la interfaz — solo se puede por base de datos (así quedó Zeeth
   como owner). Crear un panel del dueño para otorgar/quitar
   `global_role` (staff, moderador global), con cuidado especial
   para el rol dueño (confirmación reforzada; nunca quitarse el
   propio rol por accidente).
3. **Destacado por moderadores.** El Documento Maestro (sección
   8) establece que el moderador puede destacar en salas
   autorizadas, y la app ya lo permite desde la ficha del usuario
   (Destacar 7 días). Al implementar: verificar que todo moderador
   lo vea y pueda usarlo en sus salas, y que el destacado se note
   visualmente (ver punto 4).
4. **Iconos para cada rango** — DESIGNADOS por Mario el
   2026-11-23 (el Documento Maestro no los traía; solo fija los
   colores por rol). Verificado contra el set de iconos real de
   la app (Material):
   - **Destacado**: una manzana → `Icons.apple` (existe; es la
     manzana mordida).
   - **Moderador**: icono de sheriff → `Icons.local_police`
     (placa con estrella, estilo sheriff; existe). Si no convence,
     respaldo de Mario: escudo `Icons.shield`.
   - **Dueño de sala**: el mismo del moderador (sheriff/escudo).
   - **Staff**: ESPADAS (decisión final de Mario, 2026-11-23,
     sobre la credencial). El set de iconos de la app no trae
     espadas (`swords` no existe), así que se mostrará con el
     emoji ⚔️ junto al nickname.
   - **Dueño del chat (global)**: por ahora el mismo del
     moderador.
   Los iconos acompañan al color de rol ya definido; se muestran
   junto al nickname en salas, ocupantes, perfiles y Status.

## Sugerencias de testers (YouShookMe, sala Ayuda, 2026-11-23)

5. **El teclado tapa lo último escrito.** Al desplegar el teclado,
   la conversación debe subir junto con él para seguir viendo lo
   que escriben los demás mientras uno escribe. (Comportamiento
   en web; revisar también en app.)
6. **Pantalla siempre encendida con el chat abierto** (wakelock).
   En web puede ser limitado; para la app nativa es recomendable.

## Videos de YouTube y enlaces externos (propuesta de Mario, 2026-11-24)

8. **Videos de YouTube dentro de la app.** Al pegar un link de
   YouTube, el mensaje muestra una tarjeta con el video para
   verlo sin salir de ONEchat. Solo YouTube: dominios válidos
   youtube.com, www.youtube.com, m.youtube.com, youtu.be,
   music.youtube.com (incluye Shorts y directos); se extrae el
   ID del video y se usa el reproductor oficial embebido.
   Diseño acordado en principio: NO autoplay — miniatura con
   botón de play, un solo video abierto a la vez; si el dueño
   del video desactivó la inserción, se muestra tarjeta con
   aviso y enlace.
9. **Enlaces de terceros: silencio automático.** Todo link que
   no sea de YouTube, en salas (no en privados): el mensaje NO
   se publica y el usuario queda silenciado en esa sala.
   Aplicación desde el servidor (actor «sistema», con registro
   en la auditoría y contador de infracciones por usuario y
   sala), no solo desde la app. Staff y dueño exentos.
   RESUELTO por Mario (2026-11-24): SIN baneo automático.
   Escalera de silencios por infracción en la sala: 1ª = 5 min,
   2ª = 30 min, 3ª = 2 h, 4ª y siguientes = 24 h. La advertencia
   avisa de que los silencios se alargan y de que el Staff puede
   banear: las infracciones quedan en el registro de moderación
   de la sala, y el baneo lo decide el Staff (o el dueño) a la
   vista de ese historial.

10. **Avisos del sistema en Status para quienes tienen poder**
    (pedido de Mario, 2026-11-24). La pestaña Status de dueños,
    Staff y moderadores debe ser una herramienta de visión
    completa de lo que ocurre: avisos de las infracciones de los
    usuarios (incluidas las del punto 9: enlaces de terceros y
    sus silencios automáticos), de las sanciones aplicadas y de
    los reportes recibidos. Alcance por rol:
    - Dueño de sala y moderadores de sala: SOLO avisos de su(s)
      sala(s).
    - Dueño global y Staff: avisos de TODO el chat.
    Implementación: nuevos tipos de aviso en el sistema de
    notificaciones existente, generados por el servidor al
    ocurrir el evento, con una fila por destinatario según su
    alcance (así el alcance queda garantizado por construcción);
    en Status se distinguen visualmente de menciones y privados
    (p. ej. sección o icono de Moderación) y se marcan leídos
    como el resto.

11. **Ajuste de privados por usuario** (Mario, 2026-11-24).
    Cada usuario puede abrir o cerrar sus mensajes privados.
    Con los privados cerrados, SOLO le pueden escribir quienes
    él mismo tenga agregados como favoritos (sus favoritos
    siempre pueden, aunque estén cerrados). La regla se aplica
    en el servidor al enviar el privado (si no está permitido:
    el envío se rechaza con un aviso amable al remitente, sin
    revelar más de lo necesario). Ajuste en el Perfil
    (p. ej. profiles.dm_open), junto a tema/idioma/país.

12. **Avisos del sistema dentro de la sala** (Mario, 2026-11-24).
    En la propia sala se verán eventos del sistema: quién se
    conecta y quién se desconecta, y cuando alguien es
    silenciado o baneado — estas dos últimas SIN mostrar el
    nick del castigado («Un usuario fue silenciado», etc.).
    Cada usuario puede activar o desactivar la visión de estos
    mensajes del sistema en sus ajustes, para una vista más
    limpia de la sala (ajuste en el Perfil; la preferencia manda
    solo sobre lo que él ve, no sobre lo que ven los demás).

14. **Desactivar susurros** (Mario, 2026-11-24, anti-acoso).
    Ajuste por usuario, hermano del punto 11: poder cerrar los
    susurros para que nadie te susurre en las salas. Aplicación
    en el servidor al intentar susurrar (el remitente ve un
    aviso amable de que ese usuario no acepta susurros). Mismo
    criterio que los privados, CONFIRMADO por Mario: los
    favoritos del usuario siempre tienen acceso (privados y
    susurros), aunque estén cerrados. En el Perfil, privados y
    susurros quedan como dos interruptores del mismo apartado
    de contacto/privacidad.

13. **Cambiar de nick dentro de la app** (Mario, 2026-11-24).
    Desde el Perfil, el usuario puede cambiar su nickname sin
    salir de la app. Reglas: mismas validaciones del registro
    (3–20 caracteres, único sin distinguir mayúsculas) y cambio
    atómico desde el servidor — se reserva el nick nuevo y se
    libera el antiguo en la misma operación, sin dejar la cuenta
    en estados intermedios. La cuenta conserva todo (UID, roles,
    membresías, favoritos, privados): lo que cuelga del UID no
    se toca. Los mensajes antiguos mantienen el nick con el que
    se escribieron (foto del momento, como ya funciona el
    sistema). Definir al implementar un freno anti-abuso (p. ej.
    un cambio cada cierto tiempo) para evitar suplantaciones y
    confusión en las salas.

15. **Copiar texto con toque largo** (Mario, 2026-11-24). En el
    mismo menú de toque largo que hoy ofrece «Traducir», agregar
    «Copiar» (copia el texto del mensaje al portapapeles, con el
    aviso breve «Copiado»). Aplica a mensajes de sala, susurros
    y privados, igual que Traducir.

16. **Sonidos del chat, notificaciones y vibración en menciones**
    (Mario, 2026-11-24). Trabajar el apartado de sonido:
    sonidos de enviar/recibir, y alerta especial cuando te
    mencionan (sonido distintivo + vibración en el móvil).
    Ajustes por usuario en el Perfil: sonidos sí/no, vibración
    sí/no (y distinción menciones/resto si es viable). Límites
    de la web: la vibración depende del navegador (en iOS está
    muy limitada; en la app nativa se podrá completa); los
    sonidos deben ser cortos, suaves y con volumen prudente —
    espíritu MSN sin ser molestos.

17. **«Cine juntos» — película en simultáneo, SOLO Premium**
    (idea de Mario, 2026-11-24). Sala privada 1:1 donde dos
    personas ven lo mismo a la vez, sincronizado (play/pausa
    compartidos), conversando mientras tanto. Es función
    Premium y pieza de la estrategia de citas virtuales de
    Mario: experiencias compartidas que prolongan el cortejo y
    dan valor real a la suscripción. Viabilidad: la v1 realista
    es sincronizar reproducción de YouTube (aprovecha el punto
    8); NO se puede re-transmitir Netflix/HBO/etc. por licencias
    — alternativas: contenido con licencia propia o de dominio
    público, o «cada uno reproduce su copia» sincronizada por
    reloj (más complejo). Definir catálogo/fuente al diseñar la
    Etapa Premium.

## Fallos detectados en el alfa

7. **El color de nick propio no se refleja en la Sala General
   para el propio usuario.** YouShookMe puso su nick en azul: en
   Ayuda se veía, en General no (para él); desde la cuenta del
   dueño SÍ se veía su cambio en General. Error visual solo para
   el propio usuario. Causa probable: la pestaña General queda
   montada con los perfiles en caché y no refresca el color del
   propio perfil al cambiarlo en el Perfil; las salas que se abren
   después sí cargan el color nuevo.
