# ONEchat — Centro de reportes y código de conducta (implementación)

**Estado: EN VIVO** desde la v2026.11.25.1 (25-11-2026). Migración **v1.17**.
Plan aprobado por Mario el 24-11-2026: `docs/PLAN-REPORTES-Y-CONDUCTA.md`.

## Qué se construyó

### El botón «Reportar» (tres caminos)
- Botón de bandera en la barra de cada sala, botón «Reportar» en la pestaña
  Perfil y opción «Reportar» en la ficha de cada usuario.
- Tres tipos: **error** (fallos de la app), **usuario** (conducta en salas) y
  **abuso de poder** (contra dueños de sala, moderadores, Staff y dueño; la
  opción aparece cuando la persona reportada tiene poder).
- El formulario pide sala y persona cuando no hay contexto, y una descripción
  (mínimo 3 caracteres). Reportarse a sí mismo o sin acusado es rechazado por
  el servidor.

### Evidencia automática del servidor (no foto de pantalla)
Al enviar, la función `submit_report` adjunta sola, desde la base de datos:
- Reporte de usuario: los **últimos 30 mensajes** de esa sala.
- Reporte de abuso: las **últimas 20 acciones de moderación** del acusado,
  con el motivo que él mismo declaró (registro de la Etapa 3).
- Además: quién reporta, cuándo, sala, versión de la app.
La evidencia no se puede alterar ni falsificar.

### Quién ve qué (regla de oro)
| Tipo | Dueño global | Staff | Moderación de la sala | Nadie más |
|---|---|---|---|---|
| Error | ✅ | ✅ | ❌ | ❌ |
| Usuario | ✅ | ✅ | ✅ (solo su sala) | ❌ |
| Abuso de poder | ✅ **solo él** | ❌ | ❌ | ❌ |

Impuesto por RLS de Postgres y re-verificado dentro de `resolve_report`:
nadie puede cerrar un reporte que no tiene permiso de ver.

### El centro (pestaña Status)
- Entrada «Centro de reportes» visible solo para quien tiene alcance.
- Filtros: todos / nuevos / en revisión / cerrados.
- Detalle con la evidencia y acciones: pasar a revisión, resolver o
  desestimar, siempre con nota de cierre (queda registrado quién cerró).

### Código de conducta del poder
- Columna `profiles.conduct_accepted_at`; quien tiene cualquier poder y aún
  no aceptó ve el código al entrar (una vez por sesión) y debe aceptarlo:
  7 principios y la escalera de 5 castigos (llamado de atención →
  advertencia formal → suspensión del rol 7–30 días → retiro definitivo →
  Destierro solo en faltas gravísimas). «El que abusa del poder, pierde el
  poder.»
- El código también se lee desde el centro (icono de libro), sin aceptar.

## Piezas técnicas
- Tabla `public.reports_center` (RLS por alcance; sin políticas de escritura
  para clientes: todo pasa por funciones del servidor).
- Funciones: `submit_report`, `resolve_report`, `my_power_status`,
  `accept_conduct`.
- App: `lib/report_pages.dart` (formulario, centro, código),
  `services.dart`, textos ES/EN en `strings.dart`, bandera en
  `chat_page.dart`, entradas en `home_page.dart` (Status y Perfil) y en
  `user_sheet.dart`.

## Verificación (25-11-2026, sesiones reales) — 22/22
- Ronda base (10): invitado sin poder no ve el centro; aceptación de conducta
  registrada; los tres tipos se envían y devuelven id; evidencia adjunta;
  usuario común no ve reportes ni resuelve; validaciones (sin acusado, contra
  sí mismo) rechazadas.
- Ronda dueño (7): con la cuenta de prueba promovida temporalmente a dueño,
  ve los 3 tipos; la evidencia trajo exactamente 30 mensajes y 8 acciones;
  resuelve el abuso y marca el error en revisión; el cierre guarda nota y
  autor.
- Ronda Staff (5): ve error y usuario, **jamás el abuso**; no puede resolver
  el abuso (devuelve falso); sí resuelve el de usuario.
- Cierre de pruebas: rol de la cuenta de prueba restaurado a «user» y datos
  de prueba eliminados (verificado por API).
