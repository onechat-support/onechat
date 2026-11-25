#!/usr/bin/env python3
"""Extrae las letras del logo ONEchat quitando el fondo degradado (v2).

El alfa sale de desmezclar contra el fondo estimado (mediana grande).
El color NO se recupera píxel a píxel (dejaba manchas grises de la
sombra): las letras se rellenan con su degradado limpio blanco ->
celeste pálido, como el original. La píldora no se extrae (es
translúcida y salía rota): se redibuja nítida como elemento de diseño.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

SRC = "/home/hatch/workspace/projects/onechat/app/assets/logo_onechat.jpg"
OUT = "/home/hatch/workspace/projects/onechat/design"

img = Image.open(SRC).convert("RGB")
W, H = img.size
px = np.asarray(img).astype(np.float64) / 255.0

# Fondo estimado y alfa por desmezcla
bg = np.empty_like(px)
for c in range(3):
    bg[:, :, c] = ndimage.median_filter(px[:, :, c], size=61)
bg = ndimage.gaussian_filter(bg, sigma=(8, 8, 0))
fg = np.array([0.985, 0.985, 1.0])
ratio = (px - bg) / np.maximum(fg - bg, 1e-4)
alpha = np.clip(ratio.max(axis=2), 0, 1)
alpha = ndimage.gaussian_filter(alpha, sigma=0.6)
alpha = np.clip(alpha * 1.07 - 0.035, 0, 1)  # bordes un poco más firmes
alpha[alpha < 0.04] = 0

# Interior SÓLIDO sin rellenar huecos: el sombreado interno de las
# letras dejaba el alfa a 0,6-0,8 y el fondo se transparentaba como
# manchas. Una curva de niveles lo lleva a opaco; los huecos reales de
# las letras (el centro de la O, de la a, de la e) valen 0 y quedan 0.
alpha = np.clip((alpha - 0.12) / 0.5, 0, 1)
alpha = ndimage.gaussian_filter(alpha, sigma=0.45)

# Solo componentes grandes de la zona del wordmark (fuera brillos/píldora)
lab, n = ndimage.label(alpha > 0.22)
sizes = ndimage.sum(alpha > 0.22, lab, range(1, n + 1))
centroids = ndimage.center_of_mass(alpha > 0.22, lab, range(1, n + 1))
keep = np.zeros(n + 1, bool)
for i, (s, (cy, cx)) in enumerate(zip(sizes, centroids), start=1):
    if s >= 700 and cy < H * 0.74:
        keep[i] = True
alpha = np.where(keep[lab], alpha, 0)

# Opacidad total en el interior profundo (>=4 px del borde): elimina
# las últimas motas del sombreado sin cerrar los huecos de las letras
# ni el corte diagonal de la N (todos miden más de 8 px de ancho).
mask = alpha > 0.02
ero = ndimage.binary_erosion(mask, iterations=4)
base = ndimage.gaussian_filter(ero.astype(np.float64), sigma=0.9)
alpha = np.clip(np.maximum(alpha, base * 1.18), 0, 1)
# Último retoque: rellenar micro-huecos interiores (una mota en la N)
# con el alfa máximo del vecindario, solo en el interior (>=2 px).
deep2 = ndimage.binary_erosion(mask, iterations=2)
relleno = ndimage.maximum_filter(alpha, size=9)
alpha = np.where(deep2, np.maximum(alpha, relleno), alpha)

ys, xs = np.where(alpha > 0.02)
y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
pad = 10
y0, x0 = max(y0 - pad, 0), max(x0 - pad, 0)
y1, x1 = min(y1 + pad, H - 1), min(x1 + pad, W - 1)
a_crop = alpha[y0:y1 + 1, x0:x1 + 1]
h, w = a_crop.shape

def gradient(top_hex, bot_hex):
    t = np.array([int(top_hex[i:i + 2], 16) for i in (1, 3, 5)]) / 255.0
    b = np.array([int(bot_hex[i:i + 2], 16) for i in (1, 3, 5)]) / 255.0
    g = np.linspace(0, 1, h)[:, None, None]
    return np.repeat(t[None, None, :] * (1 - g) + b[None, None, :] * g, w, axis=1)

def build(rgb, name):
    out = (np.dstack([rgb, a_crop]) * 255).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    im.save(f"{OUT}/{name}")
    return im

# A) Letras blancas (degradado limpio del original)
logo_a = build(gradient("#FFFFFF", "#D9E6FF"), "logo_solo_letras.png")
# C) Letras oscuras azul -> turquesa, para fondos claros
logo_c = build(gradient("#2B6CE8", "#009E8C"), "logo_letras_oscuras.png")

# B) Letras + píldora redibujada (borde blanco, relleno translúcido, texto)
S = 3  # supersampling para que el texto salga nítido
_probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
_f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                        int(logo_a.height * 0.30 * S))
_tb = _probe.textbbox((0, 0), "Early Access • Fase Alfa", font=_f)
_ph = int((_tb[3] - _tb[1]) * 2.05)
bw = logo_a.width
bh = int(logo_a.height * 1.06) + _ph // S + 12
canvas = Image.new("RGBA", (bw * S, bh * S), (0, 0, 0, 0))
canvas.paste(logo_a.resize((bw * S, logo_a.height * S), Image.LANCZOS), (0, 0))
d = ImageDraw.Draw(canvas)
font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
fs = int(logo_a.height * 0.30 * S)
font = ImageFont.truetype(font_path, fs)
text = "Early Access • Fase Alfa"
tb = d.textbbox((0, 0), text, font=font)
tw, th = tb[2] - tb[0], tb[3] - tb[1]
ph = int(th * 2.05)
pw = int(tw * 1.22)
px1 = bw * S - int(6 * S)
py0 = int(logo_a.height * 1.06 * S)
px0, py1 = px1 - pw, py0 + ph
d.rounded_rectangle([px0, py0, px1, py1], radius=ph // 2,
                    fill=(255, 255, 255, 36), outline=(255, 255, 255, 215),
                    width=max(2, int(1.6 * S)))
d.text((px0 + (pw - tw) / 2 - tb[0], py0 + (ph - th) / 2 - tb[1]),
       text, font=font, fill=(255, 255, 255, 255))
canvas = canvas.resize((bw, bh), Image.LANCZOS)
canvas.save(f"{OUT}/logo_con_pildora.png")

def preview(logo_path, bg_hex, out_name, width=880):
    logo = Image.open(logo_path)
    r = width / logo.width
    logo = logo.resize((width, int(logo.height * r)), Image.LANCZOS)
    bgc = tuple(int(bg_hex[i:i + 2], 16) for i in (1, 3, 5))
    c = Image.new("RGB", (width + 80, logo.height + 80), bgc)
    c.paste(logo, (40, 40), logo)
    c.save(f"{OUT}/{out_name}")

preview(f"{OUT}/logo_solo_letras.png", "#121212", "preview_sobre_oscuro.png")
preview(f"{OUT}/logo_con_pildora.png", "#121212", "preview_con_pildora.png")
preview(f"{OUT}/logo_letras_oscuras.png", "#F4F7FB", "preview_sobre_claro.png")
print("OK v2")
