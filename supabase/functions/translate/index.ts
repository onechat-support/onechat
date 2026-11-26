// ONEchat — translate (Etapa 5)
// Traduce un mensaje con MyMemory (gratuito, sin clave ni tarjeta;
// el plan con DeepL quedó para cuando el dueño lo registre él
// mismo: DeepL pide tarjeta incluso en su plan gratuito).
// La interfaz con la app no cambia: entra {text, target} y sale
// {translated, detected}. Como la llama el navegador, maneja CORS
// en todas las respuestas (lección de la Etapa 1).
//
// Seguridad (auditoría 2026-11-25): exige una sesión válida
// (registrado o invitado). Sin esto, cualquiera con la clave
// pública podía quemar la cuota diaria de MyMemory y dejar sin
// traducción a los usuarios reales.
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const ES_WORDS = new Set([
  "el", "la", "los", "las", "de", "que", "en", "una", "un", "para",
  "con", "no", "hola", "gracias", "está", "estás", "esto", "pero",
  "como", "más", "muy", "bien", "sí", "yo", "tú", "mi", "es", "son",
  "por", "qué", "cuando", "también", "buenas", "todos", "nadie",
]);
const EN_WORDS = new Set([
  "the", "is", "are", "you", "hello", "thanks", "thank", "and",
  "to", "of", "in", "it", "this", "that", "for", "with", "not",
  "my", "your", "what", "when", "how", "are", "was", "were", "all",
  "good", "morning", "everyone", "welcome", "room", "please",
]);

/// Detección simple ES/EN por palabras frecuentes del chat.
/// Devuelve null si no hay señal suficiente.
function detect(text: string): string | null {
  const words = text.toLowerCase().replace(/[^\p{L}\s]/gu, " ").split(/\s+/);
  let es = 0, en = 0;
  for (const w of words) {
    if (ES_WORDS.has(w)) es++;
    if (EN_WORDS.has(w)) en++;
  }
  if (es === en) return null;
  return es > en ? "es" : "en";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await supabase.auth
    .getUser();
  if (userError || !userData.user) {
    return json({ error: "unauthorized" }, 401);
  }
  try {
    const { text, target } = await req.json();
    const clean = String(text ?? "").slice(0, 450);
    if (!clean) return json({ error: "empty_text" }, 400);
    const targetLang = target === "en" ? "en" : "es";

    const sourceLang = detect(clean) ??
      (targetLang === "es" ? "en" : "es");
    if (sourceLang === targetLang) {
      return json({ translated: clean, detected: targetLang });
    }

    const url = "https://api.mymemory.translated.net/get?q=" +
      encodeURIComponent(clean) +
      `&langpair=${sourceLang}|${targetLang}` +
      "&de=onechat.support@gmail.com";
    const res = await fetch(url);
    const data = await res.json().catch(() => null);
    const translated = data?.responseData?.translatedText as
      | string
      | undefined;
    if (
      !res.ok || !translated ||
      translated.startsWith("MYMEMORY WARNING") ||
      translated.startsWith("INVALID") ||
      translated.startsWith("QUERY LENGTH LIMIT")
    ) {
      return json({ error: "provider_error" }, 502);
    }
    return json({ translated, detected: sourceLang });
  } catch (e) {
    return json({ error: String(e) }, 400);
  }
});
