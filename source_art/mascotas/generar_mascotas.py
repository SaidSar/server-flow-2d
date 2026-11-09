"""
Genera las hojas de sprites de las mascotas (gato y perro) de Server Flow 2D.
Estilo plano, sin contorno, como el resto del arte. Cada hoja es una tira horizontal de FRAMES cuadros de
FRAME_W×FRAME_H px (lienzo 2x: 1 m del cuarto = 256 px de ancho). Las mascotas miran a la derecha; el juego
las voltea con flip_h. El punto de apoyo (los pies) está en ANCHOR, la misma coordenada en todos los cuadros.
Cuadros: 0 quieto, 1-4 caminar, 5 dormido, 6 asustado.
Uso: python3 source_art/mascotas/generar_mascotas.py   (escribe en assets/art/mascotas/)
Nota: no son renders de Blender; si algún día se renderizan, basta reemplazar los PNG conservando el diseño de la
hoja (cuadros, tamaño y ANCHOR) que documenta data/pets/mascotas.json.
"""
import math
import os
from PIL import Image, ImageDraw

FRAME_W, FRAME_H = 160, 128
ANCHOR = (80, 112)   # pies, en px del cuadro
FRAMES = 7
SS = 4               # sobremuestreo
K = 2.2 * SS         # unidades del diseño → px sobremuestreados (1 unidad = 2.2 px del lienzo 2x)
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art", "mascotas")

PETS = {
    "gato": {"kind": "cat", "body": "#f0902f", "dark": "#c96e17", "belly": "#ffe0b5"},
    "perro": {"kind": "dog", "body": "#b8854f", "dark": "#8a5d31", "belly": "#f0d9b6"},
}


def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


class Painter:
    def __init__(self, dx=0.0, dy=0.0):
        self.im = Image.new("RGBA", (FRAME_W * SS, FRAME_H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.ox = ANCHOR[0] * SS + dx * K
        self.oy = ANCHOR[1] * SS + dy * K

    def p(self, x, y):
        return (self.ox + x * K, self.oy + y * K)

    def ellipse(self, cx, cy, rx, ry, fill):
        self.d.ellipse([*self.p(cx - rx, cy - ry), *self.p(cx + rx, cy + ry)], fill=hexc(fill) if isinstance(fill, str) else fill)

    def poly(self, pts, fill):
        self.d.polygon([self.p(x, y) for x, y in pts], fill=hexc(fill) if isinstance(fill, str) else fill)

    def rrect(self, x, y, w, h, fill):
        self.d.rounded_rectangle([*self.p(x, y), *self.p(x + w, y + h)], radius=min(w, h) * 0.5 * K, fill=hexc(fill))

    def stroke(self, pts, width, fill):
        c = hexc(fill)
        pp = [self.p(x, y) for x, y in pts]
        self.d.line(pp, fill=c, width=int(width * K), joint="curve")
        r = width * K / 2
        for x, y in (pp[0], pp[-1]):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=c)

    def finish(self):
        return self.im.resize((FRAME_W, FRAME_H), Image.LANCZOS)


def bezier(p0, p1, p2, n=14):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


def frame(spec, pose, phase=0.0):
    k, body, dark, belly = spec["kind"], spec["body"], spec["dark"], spec["belly"]
    walking = pose == "walk"
    scared = pose == "scared"
    sleeping = pose == "sleep"
    swing = math.sin(phase) * 3.2 if walking else 0.0
    bob = abs(math.sin(phase)) * 1.4 if walking else 0.0
    pt = Painter(0, -bob)
    # sombra (fija, no sube con el rebote)
    sh = Painter(0, 0)
    sh.ellipse(0, 1, 19 if k == "dog" else 15, 6, (0, 0, 0, 46))
    if sleeping:
        pt.ellipse(0, -8, 19 if k == "dog" else 16, 9, body)
        pt.stroke(bezier((-14, -6), (-21, -2), (-10, 0)), 5, dark)
        pt.ellipse(10, -10, 8, 8, body)
        pt.stroke(bezier((6, -10), (9, -8), (12, -10)), 1.6, "#2a1a0c")
        if k == "cat":
            pt.poly([(4, -16), (6, -23), (11, -18)], dark)
            pt.poly([(12, -17), (16, -23), (19, -16)], dark)
        else:
            pt.ellipse(3, -6, 4, 8, dark)
        out = Image.alpha_composite(sh.im, pt.im)
        return out.resize((FRAME_W, FRAME_H), Image.LANCZOS)
    # cola
    if k == "cat":
        tw = 7 if scared else 4.5
        pt.stroke(bezier((-13, -14), (-26, -20), (-22, -34)) + [(-18, -34)], tw, dark)
    else:
        wag = math.sin(phase * 2) * 5 if walking else 0
        pt.stroke(bezier((-17, -16), (-27, -26 + wag), (-22, -32 + wag)), 5, dark)
    # patas
    pt.rrect(-11 + swing, -9, 5, 9, dark)
    pt.rrect(-4 - swing, -9, 5, 9, body)
    pt.rrect(5 + swing, -9, 5, 9, dark)
    pt.rrect(11 - swing, -9, 5, 9, body)
    # cuerpo
    rx = 18 if k == "dog" else 15
    if scared and k == "cat":
        pt.ellipse(0, -16, rx + 2, 11, body)
    else:
        pt.ellipse(0, -15, rx, 9, body)
    pt.ellipse(1, -11, rx - 5, 4.5, belly)
    if k == "cat":
        for (x0, y0, x1, y1) in ((-6, -23, -4, -17), (0, -24, 1, -17), (6, -23, 5, -17)):
            pt.stroke([(x0, y0), (x1, y1)], 2.4, dark)
    # cabeza
    hx, hy = (15, -23) if k == "dog" else (13, -23)
    pt.ellipse(hx, hy, 9 if k == "dog" else 8.5, 9 if k == "dog" else 8.5, body)
    if k == "cat":
        pt.poly([(hx - 7, hy - 4), (hx - 6, hy - 13), (hx, hy - 8)], body)
        pt.poly([(hx + 1, hy - 8), (hx + 8, hy - 13), (hx + 9, hy - 4)], body)
        pt.poly([(hx - 5, hy - 6), (hx - 4, hy - 11), (hx, hy - 8)], "#f7b3a8")
        pt.poly([(hx + 3, hy - 9), (hx + 7, hy - 12), (hx + 8, hy - 7)], "#f7b3a8")
    else:
        pt.ellipse(hx - 6, hy + 2, 4, 8, dark)
        pt.ellipse(hx + 8, hy + 4, 6, 4.6, belly)
        pt.ellipse(hx + 12, hy + 2.5, 2, 2, "#2a1a0c")
        if not walking and not scared:
            pt.poly([(hx + 7, hy + 8), (hx + 8, hy + 13), (hx + 11, hy + 9)], "#f27a8e")
    ex, ey = hx + 3, hy - 2
    if scared:
        pt.ellipse(ex, ey, 3.2, 3.2, "#ffffff")
        pt.ellipse(ex + 0.6, ey, 1.5, 1.5, "#2a1a0c")
    else:
        pt.ellipse(ex, ey, 1.9, 1.9, "#2a1a0c")
    if k == "cat":
        pt.poly([(hx + 7, hy + 2), (hx + 9, hy + 3.5), (hx + 7, hy + 4.5)], "#d9657a")
    out = Image.alpha_composite(sh.im, pt.im)
    return out.resize((FRAME_W, FRAME_H), Image.LANCZOS)


def sheet(name, spec):
    strip = Image.new("RGBA", (FRAME_W * FRAMES, FRAME_H), (0, 0, 0, 0))
    poses = [("idle", 0.0)] + [("walk", i * math.pi / 2) for i in range(4)] + [("sleep", 0.0), ("scared", 0.0)]
    assert len(poses) == FRAMES
    for i, (pose, ph) in enumerate(poses):
        strip.paste(frame(spec, pose, ph), (i * FRAME_W, 0))
    os.makedirs(OUT, exist_ok=True)
    strip.save(os.path.join(OUT, name + ".png"), optimize=True)


if __name__ == "__main__":
    for key, spec in PETS.items():
        sheet(key, spec)
        print("ok", key)
