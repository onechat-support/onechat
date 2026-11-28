// ONEchat — log-web-visit (v1.29)
// Contador de visitas de las páginas del sitio oficial
// (portada, comunidad, registro...). El sitio es estático y
// sus visitantes no tienen sesión: esta función recibe la
// página vista, el referrer y la dirección de entrada, y
// registra el ORIGEN (Instagram, buscadores, redes, directo)
// en web_visits. No guarda IP ni ningún dato personal: solo
// conteos por origen para el Panel de control del Staff.
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
/// de la dirección de entrada (con sus parámetros UTM).
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

  let payload: { page?: string; referrer?: string; landing?: string } = {};
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad_json" }, 400);
  }
  const page = String(payload.page ?? "").slice(0, 200) || null;
  const referrer = String(payload.referrer ?? "").slice(0, 500);
  const landing = String(payload.landing ?? "").slice(0, 500);
  const source = classifySource(referrer, landing);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  await admin.from("web_visits").insert({
    page,
    source,
    referrer: referrer || null,
  });

  return json({ ok: true, source }, 200);
});
