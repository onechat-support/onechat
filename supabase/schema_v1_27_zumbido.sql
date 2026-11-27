-- ONEchat · Migración v1.27 — Zumbidos en privados (nostalgia MSN)
-- Pedido de Mario, 2026-11-27: botón de zumbido en los privados.
-- Un zumbido es una fila de direct_messages con kind='nudge' y
-- body null: viaja por el mismo canal en tiempo real que los
-- mensajes, queda en el historial efímero (purga de 3 h y borrado
-- al cerrar sesión, como todo privado) y la app lo muestra como
-- aviso centrado, con sonido, vibración y sacudida de la ventana
-- al recibirlo. El límite global anti-spam (30 mensajes/min) ya
-- lo cubre; la app añade una espera de 20 s entre zumbidos.

alter table public.direct_messages
  drop constraint if exists direct_messages_kind_check;

alter table public.direct_messages
  add constraint direct_messages_kind_check
  check (kind in ('text', 'voice', 'nudge'));
