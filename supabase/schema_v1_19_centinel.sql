-- ONEchat · Migración v1.19 — Centinel: contador público
-- Expone SOLO el número agregado de amenazas mitigadas
-- (intervenciones críticas = alertas de Nivel 3 del bot).
-- Ningún dato de las tablas de seguridad se hace legible:
-- su RLS sigue siendo exclusiva de Staff/dueño; esta función
-- security definer devuelve únicamente el conteo.
create or replace function public.centinel_mitigated_count()
returns bigint language sql stable security definer set search_path = public as $$
  select count(*) from public.safety_alerts where level = 3;
$$;

grant execute on function public.centinel_mitigated_count() to anon, authenticated;
