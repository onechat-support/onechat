// ONEchat — log-visit (v1.14)
// Registra la conexión de quien entra a la app: la IP la
// observa ESTE servidor desde las cabeceras de la conexión
// real (x-forwarded-for), así que el cliente no puede
// falsificarla. Escribe en connection_log con rol de
// servicio; ese registro solo lo lee el Staff global y el
// dueño (RLS de la tabla).
// CORS en todas las respuestas (lección de la Etapa 1).
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

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "missing_token" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await anon.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "invalid_token" }, 401);
  }
  const uid = userData.user.id;

  // La IP del visitante: primera entrada de x-forwarded-for
  // (la pone la infraestructura al recibir la conexión).
  const forwarded = req.headers.get("x-forwarded-for") ?? "";
  const ip = forwarded.split(",")[0].trim() ||
    req.headers.get("x-real-ip") || "desconocida";
  const userAgent = (req.headers.get("user-agent") ?? "").slice(0, 300);

  const admin = createClient(
    url,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  const { data: profile } = await admin
    .from("profiles")
    .select("nickname")
    .eq("uid", uid)
    .maybeSingle();

  const { error: insertError } = await admin
    .from("connection_log")
    .insert({
      uid,
      nickname: profile?.nickname ?? null,
      ip,
      user_agent: userAgent || null,
    });
  if (insertError) return json({ error: "insert_failed" }, 500);

  return json({ ok: true }, 200);
});
