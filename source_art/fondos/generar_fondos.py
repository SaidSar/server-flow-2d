"""
Genera los fondos exteriores (ciudad plana de día y de noche) de Server Flow 2D.
Cada fondo es un PNG de 2400×1080 px que se ajusta a la pantalla recortando los bordes (el cuarto va al centro,
así que lo importante queda abajo y al centro). Estilo plano: franjas de color sin degradado, sin contorno.
Uso: python3 source_art/fondos/generar_fondos.py   (escribe en assets/art/fondos/)
"""
import os
import random
from PIL import Image, ImageDraw

W, H = 2400, 1080
SS = 2
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "fondos")


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


THEMES = {
    "dia": {
        "sky": ["#9fd8f5", "#b0e0f8", "#c3e8fa", "#d6f0fc", "#e8f7fd"],
        "sun": ("#fff3b0", "#ffe27a"),
        "cloud": "#ffffff",
        "far": "#a9c7dd",
        "mid": "#8aaec9",
        "near": ["#6f95b5", "#7ea3c0", "#5f86a8"],
        "window_on": "#d7ecfa",
        "window_off": "#9fc0d8",
        "ground": "#566f87",
        "road": "#3f566b",
        "line": "#e9f3fa",
        "stars": False,
    },
    "noche": {
        "sky": ["#0c1230", "#121a42", "#1a2456", "#243068", "#2f3d7a"],
        "sun": ("#f4f1d8", "#d9d6b8"),
        "cloud": "#3a4887",
        "far": "#2a3566",
        "mid": "#1f2850",
        "near": ["#171e3e", "#1b2346", "#141a37"],
        "window_on": "#ffd87a",
        "window_off": "#26305a",
        "ground": "#0f1430",
        "road": "#0a0e24",
        "line": "#5b6aa8",
        "stars": True,
    },
}


def buildings(d, rnd, x0, x1, base_y, hmin, hmax, wmin, wmax, color, theme=None, windows=False, spire=False):
    x = x0
    while x < x1:
        w = rnd.randint(wmin, wmax)
        h = rnd.randint(hmin, hmax)
        col = color if isinstance(color, str) else rnd.choice(color)
        d.rectangle([x, base_y - h, x + w, base_y], fill=hexc(col))
        if spire and rnd.random() < 0.25:
            mx = x + w // 2
            d.rectangle([mx - 3 * SS, base_y - h - 60 * SS, mx + 3 * SS, base_y - h], fill=hexc(col))
        if windows:
            step = 34 * SS
            ww, wh = 14 * SS, 20 * SS
            for wy in range(base_y - h + 28 * SS, base_y - 30 * SS, step):
                for wx in range(x + 18 * SS, x + w - ww - 8 * SS, step):
                    on = rnd.random() < (0.55 if theme["stars"] else 0.35)
                    d.rectangle([wx, wy, wx + ww, wy + wh], fill=hexc(theme["window_on"] if on else theme["window_off"]))
        x += w + rnd.randint(0, 6 * SS)


def render(name, t):
    rnd = random.Random(name)
    im = Image.new("RGB", (W * SS, H * SS), hexc(t["sky"][0]))
    d = ImageDraw.Draw(im)
    band = (H * SS * 0.62) / len(t["sky"])
    for i, c in enumerate(t["sky"]):
        bottom = H * SS if i == len(t["sky"]) - 1 else int((i + 1) * band) + 2
        d.rectangle([0, int(i * band), W * SS, bottom], fill=hexc(c))
    # Sol o luna con halo plano
    cx, cy, r = int(W * SS * 0.78), int(H * SS * 0.24), 85 * SS
    d.ellipse([cx - r * 1.7, cy - r * 1.7, cx + r * 1.7, cy + r * 1.7], fill=hexc(t["sky"][3]))
    d.ellipse([cx - r * 1.3, cy - r * 1.3, cx + r * 1.3, cy + r * 1.3], fill=hexc(t["sun"][0]) if not t["stars"] else hexc(t["sky"][4]))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hexc(t["sun"][1] if not t["stars"] else t["sun"][0]))
    if t["stars"]:
        for _ in range(90):
            sx, sy = rnd.randint(0, W * SS), rnd.randint(0, int(H * SS * 0.5))
            s = rnd.choice([2, 3, 4]) * SS
            d.rectangle([sx, sy, sx + s, sy + s], fill=hexc("#e9edff"))
    # Nubes planas
    for _ in range(7):
        x, y = rnd.randint(0, W * SS), rnd.randint(int(H * SS * 0.08), int(H * SS * 0.42))
        w = rnd.randint(160, 300) * SS
        h = rnd.randint(34, 52) * SS
        d.rounded_rectangle([x, y, x + w, y + h], radius=h // 2, fill=hexc(t["cloud"]))
        d.ellipse([x + w * 0.2, y - h * 0.7, x + w * 0.2 + h * 1.5, y + h * 0.5], fill=hexc(t["cloud"]))
        d.ellipse([x + w * 0.5, y - h * 0.95, x + w * 0.5 + h * 1.9, y + h * 0.5], fill=hexc(t["cloud"]))
    # Ciudad en 3 planos
    ground_y = int(H * SS * 0.90)
    buildings(d, rnd, -40 * SS, W * SS, ground_y, 220 * SS, 430 * SS, 90 * SS, 170 * SS, t["far"])
    buildings(d, rnd, -40 * SS, W * SS, ground_y, 170 * SS, 340 * SS, 110 * SS, 200 * SS, t["mid"], t, windows=True)
    buildings(d, rnd, -40 * SS, W * SS, ground_y, 110 * SS, 260 * SS, 130 * SS, 230 * SS, t["near"], t, windows=True, spire=True)
    # Calle
    d.rectangle([0, ground_y, W * SS, H * SS], fill=hexc(t["ground"]))
    d.rectangle([0, ground_y + 40 * SS, W * SS, H * SS], fill=hexc(t["road"]))
    for x in range(0, W * SS, 160 * SS):
        d.rectangle([x, ground_y + 90 * SS, x + 80 * SS, ground_y + 98 * SS], fill=hexc(t["line"]))
    im = im.resize((W, H), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name + ".png"), optimize=True)


if __name__ == "__main__":
    for key, theme in THEMES.items():
        render("ciudad_" + key, theme)
        print("ok", key)
