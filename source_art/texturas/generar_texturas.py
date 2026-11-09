"""
Genera los patrones (texturas) de paredes y pisos de Server Flow 2D.
Cada patrón es un PNG de 256×256 px que se repite sin costuras: 256 px = 1 m del cuarto
(ver `escala_m` en data/customization/paleta.json). Estilo plano, colores pastel.
Uso: python3 source_art/texturas/generar_texturas.py   (escribe en assets/art/texturas/)
"""
import math
import os
from PIL import Image, ImageDraw

SIZE = 256
SS = 4  # sobremuestreo para bordes suaves
S = SIZE * SS
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "texturas")


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def canvas(bg):
    im = Image.new("RGB", (S, S), hexc(bg))
    return im, ImageDraw.Draw(im)


def wrap(draw_fn):
    """Dibuja una figura en las 9 posiciones vecinas para que el patrón no tenga costuras."""
    for dx in (-S, 0, S):
        for dy in (-S, 0, S):
            draw_fn(dx, dy)


def save(im, name):
    im.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def rayas():
    im, d = canvas("#fbf3e4")
    cols = ["#f8c3d3", "#fce081", "#86d2c1", "#89c7e7"]
    n = 8
    w = S // n
    for i in range(n):
        d.rectangle([i * w, 0, i * w + w // 2, S], fill=hexc(cols[i % 4]))
    save(im, "rayas_pastel")


def lunares():
    im, d = canvas("#fdf2f5")
    cols = ["#f8c3d3", "#c5adcc", "#c6d7e8"]
    r = S // 14
    k = 0
    for row in range(4):
        for col in range(4):
            cx = (col + (0.5 if row % 2 else 0.0)) * S // 4 + S // 8
            cy = row * S // 4 + S // 8
            c = hexc(cols[(row + col) % 3])
            wrap(lambda dx, dy, cx=cx, cy=cy, c=c: d.ellipse([cx - r + dx, cy - r + dy, cx + r + dx, cy + r + dy], fill=c))
    save(im, "lunares")


def flor(d, cx, cy, r, petal, center):
    for k in range(5):
        a = k * 2 * math.pi / 5 - math.pi / 2
        px, py = cx + math.cos(a) * r * 0.62, cy + math.sin(a) * r * 0.62
        pr = r * 0.42
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=petal)
    d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=center)


def flores():
    im, d = canvas("#fff6e5")
    spots = [(0.25, 0.25, "#eb7a9d", 0.17), (0.75, 0.5, "#f08b31", 0.15), (0.3, 0.78, "#c5adcc", 0.15), (0.85, 0.12, "#89c7e7", 0.1)]
    for fx, fy, c, fr in spots:
        wrap(lambda dx, dy, fx=fx, fy=fy, c=c, fr=fr: flor(d, fx * S + dx, fy * S + dy, fr * S, hexc(c), hexc("#fce081")))
    # hojitas
    for fx, fy in [(0.55, 0.15), (0.1, 0.55), (0.6, 0.88), (0.95, 0.85)]:
        wrap(lambda dx, dy, fx=fx, fy=fy: d.ellipse([fx * S - S // 40 + dx, fy * S - S // 22 + dy, fx * S + S // 40 + dx, fy * S + S // 22 + dy], fill=hexc("#a3d369")))
    save(im, "flores")


def ondas():
    im, d = canvas("#e8f4f1")
    cols = ["#86d2c1", "#89c7e7", "#c6d7e8"]
    rows = 9  # múltiplo de 3 para que los colores también cierren sin costura
    h = S // rows
    for r in range(-1, rows + 1):
        pts = [(x, r * h + math.sin(x / S * 2 * math.pi * 2) * h * 0.28) for x in range(0, S + 1, 8)]
        d.polygon(pts + [(S, S * 2), (0, S * 2)], fill=hexc(cols[r % 3]))
    save(im, "ondas")


def rombos():
    im, d = canvas("#fbe6c9")
    cols = ["#fa7b62", "#f08b31", "#fce081", "#eb7a9d"]
    n = 4
    w = S // n
    for row in range(n):
        for col in range(n):
            cx, cy = col * w + w // 2, row * w + w // 2
            r = w * 0.42
            c = hexc(cols[(row + col) % 4])
            wrap(lambda dx, dy, cx=cx, cy=cy, c=c, r=r: d.polygon([(cx + dx, cy - r + dy), (cx + r + dx, cy + dy), (cx + dx, cy + r + dy), (cx - r + dx, cy + dy)], fill=c))
    save(im, "rombos")


def vichy():
    im, d = canvas("#ffffff")
    n = 8
    w = S // n
    base = hexc("#89c7e7")
    for i in range(0, n, 2):
        d.rectangle([i * w, 0, (i + 1) * w, S], fill=tuple(int(0.5 * 255 + 0.5 * v) for v in base))
    ov = Image.new("RGB", (S, S), (255, 255, 255))
    od = ImageDraw.Draw(ov)
    for i in range(0, n, 2):
        od.rectangle([0, i * w, S, (i + 1) * w], fill=tuple(int(0.5 * 255 + 0.5 * v) for v in base))
    im = Image.blend(im, ov, 0.5)
    # donde se cruzan se oscurece un poco: el blend ya lo hace
    save(im, "vichy_celeste")


def hojas():
    im, d = canvas("#e3f1d0")
    cols = ["#a3d369", "#b3d276", "#86d2c1"]
    for i, (fx, fy, ang) in enumerate([(0.2, 0.2, 40), (0.7, 0.3, -30), (0.4, 0.7, 70), (0.9, 0.85, -60), (0.1, 0.8, 10), (0.6, 0.05, 100)]):
        c = hexc(cols[i % 3])
        L, W = S * 0.2, S * 0.07
        a = math.radians(ang)

        def leaf(dx, dy, fx=fx, fy=fy, a=a, c=c):
            cx, cy = fx * S + dx, fy * S + dy
            pts = []
            for t in range(0, 41):
                u = t / 40
                x = (u - 0.5) * 2 * L
                y = math.sin(u * math.pi) * W
                pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
            for t in range(40, -1, -1):
                u = t / 40
                x = (u - 0.5) * 2 * L
                y = -math.sin(u * math.pi) * W
                pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
            d.polygon(pts, fill=c)
        wrap(leaf)
    save(im, "hojas")


def arcos():
    im, d = canvas("#fff3f6")
    cols = ["#f8c3d3", "#fce081", "#86d2c1", "#c5adcc"]
    r0 = S // 8
    for row in range(8):
        for col in range(4):
            cx = col * S // 4 + (S // 8 if row % 2 else 0)
            cy = row * r0 + r0
            for k, c in enumerate(reversed(cols)):
                r = r0 * (1 - 0.18 * k)
                cc = hexc(c)
                wrap(lambda dx, dy, cx=cx, cy=cy, r=r, cc=cc: d.pieslice([cx - r + dx, cy - r + dy, cx + r + dx, cy + r + dy], 180, 360, fill=cc))
    save(im, "escamas_pastel")


def tablones(name, bg, tone_a, tone_b, line):
    im, d = canvas(bg)
    rows = 4
    h = S // rows
    for r in range(rows):
        off = (r * 37 % 100) / 100 * S * 0.5
        w = S // 2
        for k in range(-1, 3):
            x0 = k * w + off
            d.rectangle([x0, r * h, x0 + w, (r + 1) * h], fill=hexc(tone_a if (k + r) % 2 == 0 else tone_b))
            d.line([x0, r * h, x0, (r + 1) * h], fill=hexc(line), width=SS * 2)
        d.line([0, r * h, S, r * h], fill=hexc(line), width=SS * 2)
    save(im, name)


def parquet():
    im, d = canvas("#d9b98c")
    tones = ["#c9a77c", "#d6b48a", "#bf9c70", "#dcbf94"]
    blocks = 2
    bs = S // blocks
    slats = 4
    g = SS * 2
    for br in range(blocks):
        for bc in range(blocks):
            horizontal = (br + bc) % 2 == 0
            for k in range(slats):
                fill = hexc(tones[(br * 2 + bc + k) % 4])
                if horizontal:
                    y0 = br * bs + k * bs // slats
                    d.rectangle([bc * bs + g, y0 + g, (bc + 1) * bs - g, y0 + bs // slats - g], fill=fill)
                else:
                    x0 = bc * bs + k * bs // slats
                    d.rectangle([x0 + g, br * bs + g, x0 + bs // slats - g, (br + 1) * bs - g], fill=fill)
    save(im, "parquet_miel")


def damero():
    im, d = canvas("#f4efe6")
    n = 4
    w = S // n
    for r in range(n):
        for c in range(n):
            if (r + c) % 2 == 0:
                d.rectangle([c * w, r * w, (c + 1) * w, (r + 1) * w], fill=hexc("#8fa77a"))
    save(im, "damero_salvia")


def azulejos(name, base, grout, accent):
    im, d = canvas(grout)
    n = 4
    w = S // n
    g = SS * 3
    for r in range(n):
        for c in range(n):
            d.rounded_rectangle([c * w + g, r * w + g, (c + 1) * w - g, (r + 1) * w - g], radius=SS * 4, fill=hexc(base))
            if (r * 3 + c) % 5 == 0:
                cx, cy = c * w + w // 2, r * w + w // 2
                d.ellipse([cx - w // 6, cy - w // 6, cx + w // 6, cy + w // 6], fill=hexc(accent))
    save(im, name)


def mosaico():
    im, d = canvas("#fff8ee")
    cols = ["#f8c3d3", "#86d2c1", "#fce081", "#89c7e7", "#c5adcc", "#fa7b62"]
    n = 8
    w = S // n
    g = SS * 2
    k = 0
    for r in range(n):
        for c in range(n):
            d.rectangle([c * w + g, r * w + g, (c + 1) * w - g, (r + 1) * w - g], fill=hexc(cols[(r * 5 + c * 3 + (r * c)) % 6]))
    save(im, "mosaico_pastel")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rayas(); lunares(); flores(); ondas(); rombos(); vichy(); hojas(); arcos()
    tablones("tablones_claros", "#e1c7a0", "#d8bb91", "#e6cfac", "#bfa07a")
    tablones("tablones_nogal", "#8a6a4a", "#7d5e40", "#93734f", "#5c4430")
    parquet(); damero()
    azulejos("azulejo_celeste", "#bfe0f2", "#ffffff", "#89c7e7")
    mosaico()
    print("Texturas escritas en", os.path.abspath(OUT))
