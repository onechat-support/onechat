// ONEchat — delete-account
// Eliminación de cuenta pedida por el propio usuario (requisito
// de Google Play: poder borrar la cuenta desde la app Y desde la
// web). Dos modos:
//  - App: llega el JWT del usuario en Authorization; si la cuenta
//    es registrada se exige además su contraseña en {password}.
//    Las cuentas de invitado se borran solo con su sesión.
//  - Web (getonechat.com/eliminar-cuenta.html): llega
//    {nickname, password} sin sesión; la contraseña se verifica
//    contra el correo interno de la cuenta, que nunca se expone.
// Borra los archivos de la Galería, todo el contenido y el perfil
// (función purge_user_data, migración v1.21) y el usuario de
// Auth. Las evidencias de seguridad ya reportadas a la autoridad
// se conservan desvinculadas, como dicen los Términos.
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const admin = createClient(
      url,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    let uid: string | null = null;

    const authHeader = req.headers.get("Authorization") ?? "";
    const asUser = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await asUser.auth.getUser();

    if (userData?.user) {
      // Modo app (o web con sesión): el JWT manda.
      uid = userData.user.id;
      const { data: prof } = await admin
        .from("profiles")
        .select("is_guest,email")
        .eq("uid", uid)
        .maybeSingle();
      if (!prof) return json({ error: "profile_not_found" }, 404);
      if (!prof.is_guest) {
        const password = String(body?.password ?? "");
        if (!password || !prof.email) {
          return json({ error: "password_required" }, 400);
        }
        const verify = createClient(url, anonKey);
        const { error } = await verify.auth.signInWithPassword({
          email: prof.email,
          password,
        });
        if (error) return json({ error: "invalid_password" }, 401);
      }
    } else {
      // Modo web sin sesión: nickname + contraseña.
      const nickname = String(body?.nickname ?? "").trim().toLowerCase();
      const password = String(body?.password ?? "");
      if (!nickname || !password) {
        return json({ error: "credentials_required" }, 400);
      }
      const { data: prof } = await admin
        .from("profiles")
        .select("uid,email,is_guest")
        .eq("nickname_lower", nickname)
        .maybeSingle();
      if (!prof || prof.is_guest || !prof.email) {
        return json({ error: "invalid_credentials" }, 401);
      }
      const verify = createClient(url, anonKey);
      const { data: signIn, error } = await verify.auth
        .signInWithPassword({ email: prof.email, password });
      if (error || !signIn.user) {
        return json({ error: "invalid_credentials" }, 401);
      }
      uid = signIn.user.id;
    }

    // Archivos de la Galería: carpeta <uid>/ del bucket gallery.
    for (let i = 0; i < 10; i++) {
      const { data: files } = await admin.storage
        .from("gallery")
        .list(uid, { limit: 100 });
      if (!files || files.length === 0) break;
      await admin.storage
        .from("gallery")
        .remove(files.map((f) => `${uid}/${f.name}`));
    }

    const { error: purgeError } = await admin.rpc("purge_user_data", {
      p_uid: uid,
    });
    if (purgeError) return json({ error: "purge_failed" }, 500);

    const { error: deleteError } = await admin.auth.admin.deleteUser(uid);
    if (deleteError) return json({ error: "delete_failed" }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 400);
  }
});
