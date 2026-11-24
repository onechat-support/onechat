#!/usr/bin/env python3
"""Herramienta del alfa de ONEchat: sesión persistente de PruebaZeth.

Uso:
  alpha_tool.py init            Crea la sesión invitada y el perfil.
  alpha_tool.py whoami          Muestra el perfil actual.
  alpha_tool.py post SLUG TEXTO Publica un mensaje en la sala.
  alpha_tool.py fetch           Actividad nueva desde la última marca
                                (no avanza la marca).
  alpha_tool.py mark            Avanza la marca hasta lo último visto.

La sesión (token de refresco) vive en .alpha/session.json y se
renueva en cada uso; es una cuenta invitada de pruebas del equipo.
"""
import json
import os
import subprocess
from urllib.parse import quote
import sys

BASE = "https://jsdyoqmgdkqlkucebjmt.supabase.co"
KEY = "sb_publishable_FE28e094cucvLYdDFlnxKQ_dxlKjXO-"
HERE = os.path.dirname(os.path.abspath(__file__))
SESSION = os.path.join(HERE, "session.json")
STATE = os.path.join(HERE, "state.json")


def call(method, path, token=None, body=None, prefer=None):
    cmd = ["curl", "-s", "-X", method, BASE + path,
           "-H", f"apikey: {KEY}", "-w", "\n%{http_code}"]
    if token:
        cmd += ["-H", f"Authorization: Bearer {token}"]
    if prefer:
        cmd += ["-H", f"Prefer: {prefer}"]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    raw, _, code = out.rpartition("\n")
    try:
        parsed = json.loads(raw) if raw else None
    except Exception:
        parsed = raw
    return int(code), parsed


def save_session(data):
    with open(SESSION, "w") as f:
        json.dump(data, f)
    os.chmod(SESSION, 0o600)


def load_session():
    with open(SESSION) as f:
        return json.load(f)


def refresh():
    """Devuelve (access_token, uid) renovando y guardando la sesión."""
    s = load_session()
    code, r = call("POST", "/auth/v1/token?grant_type=refresh_token",
                   body={"refresh_token": s["refresh_token"]})
    if code != 200:
        raise SystemExit(f"No se pudo renovar la sesión ({code}): {r}")
    save_session({"refresh_token": r["refresh_token"],
                  "uid": r["user"]["id"]})
    return r["access_token"], r["user"]["id"]


def room_by_slug(token, slug):
    _, rows = call("GET", f"/rest/v1/rooms?slug=eq.{slug}&select=id,name",
                   token=token)
    return rows[0] if rows else None


def init():
    code, r = call("POST", "/auth/v1/signup", body={})
    if code != 200 or "access_token" not in (r or {}):
        raise SystemExit(f"Registro anónimo falló ({code}): {r}")
    save_session({"refresh_token": r["refresh_token"],
                  "uid": r["user"]["id"]})
    token, uid = r["access_token"], r["user"]["id"]
    code, resp = call("POST", "/rest/v1/profiles", token=token, body={
        "uid": uid,
        "nickname": "PruebaZeth",
        "nickname_lower": "pruebazeth",
        "is_guest": True,
        "bio": "Parte del equipo de ONEchat. Estamos en acceso "
               "anticipado: reviso las salas periódicamente y "
               "respondo en Ayuda.",
    }, prefer="return=minimal")
    if code not in (200, 201):
        raise SystemExit(f"Crear perfil falló ({code}): {resp}")
    for slug in ("general", "ayuda"):
        room = room_by_slug(token, slug)
        if room:
            call("POST", "/rest/v1/room_members", token=token,
                 body={"room_id": room["id"], "uid": uid},
                 prefer="resolution=ignore-duplicates,return=minimal")
    print("OK: perfil PruebaZeth creado, uid", uid)


def whoami():
    token, uid = refresh()
    _, rows = call("GET", f"/rest/v1/profiles?uid=eq.{uid}&select=*",
                   token=token)
    print(json.dumps(rows, ensure_ascii=False, indent=1))


def post(slug, text):
    token, uid = refresh()
    room = room_by_slug(token, slug)
    if not room:
        raise SystemExit(f"Sala no encontrada: {slug}")
    call("POST", "/rest/v1/room_members", token=token,
         body={"room_id": room["id"], "uid": uid},
         prefer="resolution=ignore-duplicates,return=minimal")
    code, resp = call("POST", "/rest/v1/room_messages", token=token, body={
        "room_id": room["id"], "sender_uid": uid, "body": text,
        "sender_nickname": "PruebaZeth",
    }, prefer="return=minimal")
    if code not in (200, 201):
        raise SystemExit(f"Publicar falló ({code}): {resp}")
    print(f"OK: mensaje publicado en {slug}")


def load_state():
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {"last_msg_id": 0, "last_profile_at": "1970-01-01T00:00:00Z"}


def fetch():
    token, _ = refresh()
    st = load_state()
    _, profiles = call(
        "GET", "/rest/v1/profiles?select=nickname,is_guest,created_at"
        "&created_at=gt." + quote(st["last_profile_at"])
        + "&order=created_at.asc",
        token=token)
    _, rooms = call("GET", "/rest/v1/rooms?select=id,slug", token=token)
    slug_by_id = {r["id"]: r["slug"] for r in rooms}
    _, msgs = call(
        "GET", "/rest/v1/room_messages?select=id,room_id,sender_nickname,"
        f"body,created_at&id=gt.{st['last_msg_id']}&order=id.asc&limit=200",
        token=token)
    out = {"perfiles_nuevos": profiles or [], "mensajes": [
        {"sala": slug_by_id.get(m["room_id"], "?"),
         "de": m["sender_nickname"], "texto": m["body"],
         "hora": m["created_at"], "id": m["id"]} for m in (msgs or [])]}
    print(json.dumps(out, ensure_ascii=False, indent=1))


def mark():
    token, _ = refresh()
    st = load_state()
    _, msgs = call("GET", "/rest/v1/room_messages?select=id"
                   "&order=id.desc&limit=1", token=token)
    _, profs = call("GET", "/rest/v1/profiles?select=created_at"
                    "&order=created_at.desc&limit=1", token=token)
    if msgs:
        st["last_msg_id"] = msgs[0]["id"]
    if profs:
        st["last_profile_at"] = profs[0]["created_at"]
    with open(STATE, "w") as f:
        json.dump(st, f)
    print("Marca avanzada:", st)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "init":
        init()
    elif cmd == "whoami":
        whoami()
    elif cmd == "post":
        post(sys.argv[2], sys.argv[3])
    elif cmd == "fetch":
        fetch()
    elif cmd == "mark":
        mark()
    else:
        raise SystemExit(__doc__)
