// ONEchat — acceso con nickname + contraseña.
// El correo de la cuenta vive solo en el registro: esta función lo
// resuelve internamente (rol de servicio) y devuelve la sesión,
// sin exponer jamás el correo al cliente.
//
// CORS: imprescindible. La app corre en un navegador (GitHub Pages)
// y sin estas cabeceras el navegador bloquea la llamada ANTES de
// que llegue al servidor (fue la causa de que el acceso por
// nickname fallara siempre desde la app aunque la clave fuera
// correcta; por API directa funcionaba).
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  let payload: { nickname?: string; password?: string } = {};
  try {
    payload = await req.json();
  } catch {
    // cuerpo vacío o no-JSON: cae en missing_fields
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
