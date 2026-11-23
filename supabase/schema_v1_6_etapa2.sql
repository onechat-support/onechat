-- ONEchat migración v1.6 — Etapa 2 (social avanzado)
-- 1) Susurros en tiempo real (la publicación ya traía mensajes de
--    sala, notificaciones y privados; faltaban los susurros).
alter publication supabase_realtime add table public.whispers;

-- 2) Marcar privados como leídos: solo el DESTINATARIO (participante
--    que no envió el mensaje) puede actualizarlo (read_at).
create policy dm_mark_read on public.direct_messages
  for update using (
    sender_uid <> auth.uid()
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.user_a = auth.uid() or c.user_b = auth.uid()))
  ) with check (
    sender_uid <> auth.uid()
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.user_a = auth.uid() or c.user_b = auth.uid()))
  );
