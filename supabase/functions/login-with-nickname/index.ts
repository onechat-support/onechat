// ONEchat — Acceso con nickname + contraseña.
// El correo queda solo para el registro y la recuperación: esta
// función lo resuelve internamente (service role) y jamás lo expone
// al cliente. Devuelve la sesión lista para usar.
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  let payload: { nickname?: string; password?: string } = {};
  try {
    payload = await req.json();
  } catch {
    // cuerpo inválido: se trata como campos faltantes
  }
  const nickname = (payload.nickname ?? "").trim().toLowerCase();
  const password = payload.password ?? "";
  if (!nickname || !password) return json({ error: "missing_fields" }, 400);

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const admin = createClient(
    url,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  const { data: profile } = await admin
    .from("profiles")
    .select("email, is_guest")
    .eq("nickname_lower", nickname)
    .maybeSingle();
  if (!profile || profile.is_guest || !profile.email) {
    return json({ error: "invalid_credentials" }, 401);
  }
  const client = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "");
  const { data, error } = await client.auth.signInWithPassword({
    email: profile.email,
    password,
  });
  if (error || !data.session) {
    return json({ error: "invalid_credentials" }, 401);
  }
  return json({ session: data.session }, 200);
});
