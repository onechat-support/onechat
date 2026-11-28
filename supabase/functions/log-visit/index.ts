// ONEchat — log-visit (v1.14, ampliada en v1.15; v4 en v1.29:
// registra también el ORIGEN de la visita — Instagram,
// buscadores, redes, directo — declarado por la app desde el
// referrer y los parámetros UTM de la dirección de entrada)
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

/// Clasifica el origen de una visita a partir del referrer y
/// de la dirección de entrada (con sus parámetros UTM). Los
/// UTM mandan: son la señal que la propia plataforma pone en
/// sus enlaces (p. ej. el enlace de la bio de Instagram).
function classifySource(referrer: string, landing: string): string {
  let utmSource = "", utmMedium = "";
  try {
    const u = new URL(landing);
    utmSource = (u.searchParams.get("utm_source") ?? "").toLowerCase();
    utmMedium = (u.searchParams.get("utm_medium") ?? "").toLowerCase();
  } catch { /* landing sin formato: se sigue con el referrer */ }
  const s = utmSource;
  if (s.includes("instagram") || s === "ig") return "instagram";
  if (s.includes("facebook") || s === "fb") return "facebook";
  if (s.includes("whatsapp")) return "whatsapp";
  if (s.includes("tiktok")) return "tiktok";
  if (s.includes("youtube") || s === "yt") return "youtube";
  if (s.includes("twitter") || s === "x") return "x";
  if (utmMedium === "organic") return "buscadores";
  if (utmMedium === "cpc" || utmMedium === "ppc") return "publicidad";
  let host = "";
  try {
    host = new URL(referrer).hostname.toLowerCase();
  } catch { /* referrer vacío o sin formato */ }
  if (!host) return "directo";
  if (host.includes("instagram")) return "instagram";
  if (host.includes("facebook") || host.includes("fb.")) return "facebook";
  if (host.includes("whatsapp")) return "whatsapp";
  if (host.includes("tiktok")) return "tiktok";
  if (host.includes("youtube")) return "youtube";
  if (
    host.includes("google") || host.includes("bing") ||
    host.includes("duckduckgo") || host.includes("yahoo") ||
    host.includes("ecosia") || host.includes("startpage") ||
    host.includes("search")
  ) return "buscadores";
  if (host.includes("getonechat.com")) return "interno";
  return "otros";
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

  let payload: {
    device_id?: string;
    fingerprint?: string;
    referrer?: string;
    landing?: string;
    client_hint?: string;
  } = {};
  try {
    payload = await req.json();
  } catch {
    // Sin cuerpo: se registra la visita sin dispositivo.
  }
  const deviceId = String(payload.device_id ?? "").slice(0, 80) || null;
  const fingerprint = String(payload.fingerprint ?? "").slice(0, 80) || null;
  const referrer = String(payload.referrer ?? "").slice(0, 500);
  const landing = String(payload.landing ?? "").slice(0, 500);
  const source = payload.client_hint === "app"
    ? "app"
    : classifySource(referrer, landing);

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

  // País de la conexión (v1.25): la app lo usa para abrir la
  // sala del país junto a General. Caché por IP: si esta IP ya
  // se resolvió en una visita anterior, se reutiliza el dato y
  // no se consulta ningún servicio externo.
  let country: string | null = null;
  const { data: prevRow } = await admin
    .from("connection_log")
    .select("country")
    .eq("ip", ip)
    .not("country", "is", null)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (prevRow?.country) {
    country = prevRow.country as string;
  } else if (
    ip !== "desconocida" && !ip.startsWith("127.") && ip !== "::1" &&
    !ip.startsWith("192.168.") && !ip.startsWith("10.")
  ) {
    try {
      const r = await fetch(`https://ipapi.co/${ip}/country/`, {
        signal: AbortSignal.timeout(2500),
      });
      if (r.ok) {
        const c = (await r.text()).trim().toUpperCase();
        if (/^[A-Z]{2}$/.test(c)) country = c;
      }
    } catch { /* Sin país: la app no abre sala automática. */ }
    if (!country) {
      try {
        const r = await fetch(
          `http://ip-api.com/json/${ip}?fields=countryCode`,
          { signal: AbortSignal.timeout(2500) },
        );
        if (r.ok) {
          const j = await r.json();
          if (j?.countryCode) country = String(j.countryCode).toUpperCase();
        }
      } catch { /* Ídem. */ }
    }
  }

  // La visita queda registrada SIEMPRE (también la del
  // desterrado que intenta volver: es evidencia).
  await admin.from("connection_log").insert({
    uid,
    nickname: profile?.nickname ?? null,
    ip,
    user_agent: userAgent || null,
    device_id: deviceId,
    fingerprint,
    country,
    source,
    referrer: referrer || null,
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

  return json({ ok: true, country }, 200);
});
