# ONEchat — Etapa 2: Social avanzado

Completada el 2026-11-23. Sobre el MVP de la Etapa 1.

## Qué incluye
- **Susurros**: mensajes privados dentro de la sala, en morado y
  cursiva («X te susurra» / «Susurras a X»). Solo los ven emisor y
  destinatario: la base los entrega únicamente a ellos (RLS), y sin
  sesión la tabla responde 401. Desde la ficha de un usuario
  («Susurrar») o tocando un susurro recibido (responder). Al enviar,
  el destinatario recibe aviso en su Sala Status.
- **Mensajes privados 1:1**: pestaña «Privados» con la lista de
  conversaciones (último mensaje, hora, no leídos con distintivo),
  chat privado en tiempo real, marcado de leídos (solo el
  destinatario puede marcar, por regla de la base) y aviso en
  Status. Se inicia desde la ficha de cualquier usuario
  («Mensaje privado»).
- Las menciones y los favoritos ya venían del MVP; con esto la
  etapa queda completa según el roadmap adaptado.

## Cambios técnicos
- Migración v1.6: susurros en la publicación de tiempo real y
  política `dm_mark_read` en direct_messages.
- Sin funciones nuevas de servidor: todo es RLS + consultas del
  cliente (conversations con pareja en orden canónico user_a<user_b).

## Verificación (API, sesiones reales)
- Susurro: lo ve el destinatario; un tercer usuario ve cero;
  sin sesión, 401.
- Privados: el tercero lee cero; el destinatario marca leído; el
  emisor NO puede marcar leído su propio mensaje.
- Análisis sin problemas, prueba de widgets aprobada, compilación
  web y publicación verificadas por hash.
