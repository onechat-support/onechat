# Pulido: sala Ayuda conectada al HUD del Staff + endurecimiento

Pedido de Mario (2026-11-23), antes de la Etapa 6: que la sala
Ayuda esté conectada al HUD de los miembros del Staff.

## Cómo quedó

- **Icono exclusivo**: en la barra de la app aparece un icono de
  agente de soporte SOLO si el usuario tiene rol global `staff` u
  `owner`. Visible en todas las pestañas (en General va dentro de
  la barra de la sala, vía `extraActions` de ChatPage).
- **Siempre presentes**: el widget `_StaffHelpButton` (home_page)
  se suscribe en vivo a los mensajes de Ayuda y mantiene la
  membresía silenciosa del miembro del Staff en la sala; no hace
  falta estar dentro de la sala para enterarse.
- **Contador de sin leer**: mensajes de usuarios (no Staff)
  posteriores al marcador `room_members.last_read_at` del miembro
  (migración v1.10). Los mensajes del propio Staff no cuentan.
  Tocar el icono marca leído, entra directo a Ayuda, y al salir
  vuelve a marcar leído.
- Servicios nuevos: `staffUids()`, `helpUnreadCount(roomId)`,
  `markHelpRead(roomId)`. Textos: `help.staffTooltip` (ES/EN).

Verificado por API: unirse, conteo (2 → leído → 0 → nuevo → 1),
marcador persistente.

## Seguridad: autopromoción cerrada (v1.11)

Durante la verificación se detectó un agujero grave: la política
«actualiza tu propia fila» permitía a cualquier usuario, con una
llamada directa a la API, cambiarse `profiles.global_role` a
`owner` (dueño de la plataforma) y editar su fila de
`room_members` (rol, quitarse baneos y silencios), saltándose las
funciones de moderación de la Etapa 3.

Migración v1.11 (`schema_v1_11_seguridad.sql`): disparadores
`freeze_profile_role` y `freeze_member_sanctions` que restauran
esos campos cuando quien actualiza es el propio usuario desde la
app. Las funciones security-definer (actualizan filas de otros) y
el panel (sin sesión de app) no se ven afectados.

Verificación posterior (8 controles): autopromoción global y de
sala bloqueadas; el silenciado no puede quitarse el silencio;
silenciar/levantar por la vía oficial sigue funcionando; editar
el perfil y el marcador de lectura siguen funcionando.
