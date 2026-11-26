-- ONEchat · Migración v1.20a — Auditoría de seguridad 2026-11-25 (hallazgo 1)
-- Cierra la fuga de correos: nadie (ni siquiera con sesión) puede
-- leer profiles.email vía API. El ingreso por nickname no se afecta:
-- la función login-with-nickname lee el correo con la clave de
-- servicio en el servidor. La app solo escribe la columna al
-- registrarse (el permiso de inserción no se toca) y la web pública
-- nunca la solicita.
revoke select (email) on public.profiles from anon, authenticated;
