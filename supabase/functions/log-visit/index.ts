// ONEchat — log-visit (v1.14, ampliada en v1.15)
// Puerta de entrada de la app: registra la conexión (la IP
// la observa ESTE servidor desde las cabeceras reales, el
// cliente no puede falsificarla) y verifica el Destierro
// (Fase S1 antitóxicos): si la cuenta, el dispositivo o la
// IP están desterrados, devuelve {banned:true,...} y la
// app muestra la pantalla de acceso revocado.
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

  let payload: { device_id?: string; fingerprint?: string } = {};
  try {
    payload = await req.json();
  } catch {
    // Sin cuerpo: se registra la visita sin dispositivo.
  }
  const deviceId = String(payload.device_id ?? "").slice(0, 80) || null;
  const fingerprint = String(payload.fingerprint ?? "").slice(0, 80) || null;

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await anon.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "invalid_token" }, 401);
  }
  const uid = userData.user.id;

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

  // La visita queda registrada SIEMPRE (también la del
  // desterrado que intenta volver: es evidencia).
  await admin.from("connection_log").insert({
    uid,
    nickname: profile?.nickname ?? null,
    ip,
    user_agent: userAgent || null,
    device_id: deviceId,
    fingerprint,
  });

  // Control del Destierro: cuenta, dispositivo (id o
  // huella) e IP, vigentes (sin levantar y sin vencer).
  const nowIso = new Date().toISOString();
  const { data: bans } = await admin
    .from("platform_bans")
    .select("kind, value, expires_at")
    .is("lifted_at", null)
    .or(`expires_at.is.null,expires_at.gt.${nowIso}`);
  const active = (bans ?? []).filter((b) => {
    if (b.kind === "account") return b.value === uid;
    if (b.kind === "ip") return b.value === ip;
    if (b.kind === "device") {
      return (deviceId !== null && b.value === deviceId) ||
        (fingerprint !== null && b.value === fingerprint);
    }
    return false;
  });
  if (active.length > 0) {
    const permanent = active.some((b) => b.expires_at === null);
    const latest = active
      .map((b) => b.expires_at)
      .filter((e): e is string => e !== null)
      .sort()
      .at(-1) ?? null;
    return json({ banned: true, permanent, expires_at: latest }, 200);
  }

  return json({ ok: true }, 200);
});
