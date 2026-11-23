# ONEchat — Etapa 3: Moderación completa

Completada el 2026-11-23. Sobre la Etapa 2.

## Qué incluye
- **Roles**: dueño de la plataforma (Mario, «Zeeth», rol global
  owner), staff global, dueño de sala y moderadores de sala. Los
  roles se ven en el perfil y en la lista de ocupantes; Premium
  nunca otorga poderes (regla del Documento Maestro).
- **Sanciones por sala**: silenciar (10 min / 1 h / 24 h), quitar
  silencio, banear, quitar baneo, expulsar y destacar por 7 días
  (sin poderes). Desde la ficha de cualquier usuario, con
  confirmación en las acciones serias.
- **Cumplimiento en el servidor**: el silenciado no puede publicar
  ni susurrar en esa sala (la base rechaza el envío) y la app le
  muestra el aviso y desactiva el campo; el baneado ve una
  pantalla de baneo al entrar y tampoco puede escribir.
- **Panel de moderación** (botón de escudo en la sala, solo para
  quien modera): sanciones vigentes con opción de levantarlas y
  registro de auditoría de la sala.
- **Protecciones**: nadie se sanciona a sí mismo; el dueño de la
  sala solo puede ser moderado por staff global; el staff solo
  por el dueño de la plataforma.

## Cambios técnicos
- Migración v1.7: funciones del servidor `can_moderate`,
  `can_manage_roles`, `moderate_member` (aplica la sanción y
  escribe la auditoría en la misma operación) y `set_room_role`;
  la política de susurros ahora también respeta silencio/baneo;
  política de lectura de `mod_actions` (actor, afectado,
  moderadores de la sala y staff).
- El esquema v0 ya traía `global_role`, `room_members.role`,
  `muted_until`, `banned_at` y la política de mensajes que bloquea
  a sancionados: la etapa agregó la capa de permisos y la interfaz.

## Verificación (API, sesiones reales)
19 comprobaciones: sin poderes no se puede sancionar; el dueño
silencia y el silenciado no escribe ni susurra (403); el dueño
nombra moderador y ese moderador sanciona; baneo y rehabilitación
completos; la expulsión borra la membresía; la auditoría es
completa para quien modera y limitada a lo propio para el
afectado. Análisis sin problemas, prueba aprobada y publicación
verificada por hash.
