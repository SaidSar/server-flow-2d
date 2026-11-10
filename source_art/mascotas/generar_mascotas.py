"""
Genera las hojas de sprites de las mascotas (gato, perro, conejo y tortuga) de Server Flow 2D.
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
    # Conejo y tortuga son más pequeños: "size" escala todo el dibujo (los pies siguen en ANCHOR).
    "conejo": {"kind": "rabbit", "body": "#fbfcff", "dark": "#dfe2ec", "belly": "#ffffff", "pink": "#f6b8cf", "size": 0.8},
    "tortuga": {"kind": "turtle", "body": "#4f8a3a", "dark": "#3b6b2b", "belly": "#e8dcae", "skin": "#8cc760", "scute": "#6fb04f", "size": 0.85},
}


def hexc(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


class Painter:
    def __init__(self, dx=0.0, dy=0.0, scale=1.0):
        self.im = Image.new("RGBA", (FRAME_W * SS, FRAME_H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.k = K * scale
        self.ox = ANCHOR[0] * SS + dx * self.k
        self.oy = ANCHOR[1] * SS + dy * self.k

    def p(self, x, y):
        return (self.ox + x * self.k, self.oy + y * self.k)

    def ellipse(self, cx, cy, rx, ry, fill):
        self.d.ellipse([*self.p(cx - rx, cy - ry), *self.p(cx + rx, cy + ry)], fill=hexc(fill) if isinstance(fill, str) else fill)

    def poly(self, pts, fill):
        self.d.polygon([self.p(x, y) for x, y in pts], fill=hexc(fill) if isinstance(fill, str) else fill)

    def rrect(self, x, y, w, h, fill):
        self.d.rounded_rectangle([*self.p(x, y), *self.p(x + w, y + h)], radius=min(w, h) * 0.5 * self.k, fill=hexc(fill))

    def stroke(self, pts, width, fill):
        c = hexc(fill)
        pp = [self.p(x, y) for x, y in pts]
        self.d.line(pp, fill=c, width=int(width * self.k), joint="curve")
        r = width * self.k / 2
        for x, y in (pp[0], pp[-1]):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=c)

    def finish(self):
        return self.im.resize((FRAME_W, FRAME_H), Image.LANCZOS)


def bezier(p0, p1, p2, n=14):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


def rot_ellipse(pt, pivot, center, rx, ry, deg, fill):
    """Elipse con centro `center` (relativo al pivote) girada `deg` grados alrededor del pivote (sentido horario)."""
    a = math.radians(deg)
    pts = []
    for i in range(28):
        t = 2 * math.pi * i / 28
        x, y = center[0] + rx * math.cos(t), center[1] + ry * math.sin(t)
        pts.append((pivot[0] + x * math.cos(a) - y * math.sin(a), pivot[1] + x * math.sin(a) + y * math.cos(a)))
    pt.poly(pts, fill)


def frame_rabbit(spec, pose, phase=0.0):
    """Conejo blanco: salta al caminar; dormido en bolita; asustado con las orejas pegadas."""
    body, dark, pink, size = spec["body"], spec["dark"], spec["pink"], spec["size"]
    walking, scared, sleeping = pose == "walk", pose == "scared", pose == "sleep"
    hop = (0.35, 1.0, 0.35, 0.0)[int(round(phase / (math.pi / 2))) % 4] * 8 if walking else 0.0
    swing = (-3, 0, 3, 0)[int(round(phase / (math.pi / 2))) % 4] if walking else 0
    pt = Painter(0, -hop, size)
    sh = Painter(0, 0, size)
    sh.ellipse(0, 1, 15 - hop * 0.3, 5.5, (0, 0, 0, 46))
    if sleeping:
        pt.ellipse(-14, -9, 4.6, 4.6, "#ffffff")
        pt.ellipse(0, -8, 15, 9, body)
        pt.ellipse(9, -8, 7.5, 7.5, body)
        rot_ellipse(pt, (5, -13), (0, -9), 3.6, 10.5, -82, dark)
        rot_ellipse(pt, (5, -13), (0, -9), 1.8, 7, -82, pink)
        pt.stroke(bezier((8, -9), (11, -7), (14, -9)), 1.6, "#2a1a0c")
        pt.ellipse(15.4, -6.6, 1.5, 1.5, "#f06fa4")
        out = Image.alpha_composite(sh.im, pt.im)
        return out.resize((FRAME_W, FRAME_H), Image.LANCZOS)
    hx, hy = 13, -22
    pt.ellipse(-16, -15, 5.2, 5.2, "#ffffff")                   # cola de pompón
    pt.ellipse(-7 - swing * 0.4, -9, 8, 7, dark)                # muslo
    pt.ellipse(-3 - swing, -2, 7, 2.6, body)                    # pata trasera
    pt.ellipse(9 + swing, -3, 3.4, 2.7, body)                   # pata delantera
    pt.ellipse(0, -15, 14, 9, body)
    pt.ellipse(2, -11.5, 8, 4, "#ffffff")
    a_back, a_front = (-84, -70) if scared else (-8, 9)
    rot_ellipse(pt, (hx - 4, hy - 6), (0, -10), 3.6, 11, a_back, dark)
    rot_ellipse(pt, (hx - 4, hy - 6), (0, -10), 1.8, 7.4, a_back, pink)
    pt.ellipse(hx, hy, 8.2, 8.2, body)
    rot_ellipse(pt, (hx + 1, hy - 6), (0, -10), 3.8, 11.5, a_front, body)
    rot_ellipse(pt, (hx + 1, hy - 6), (0, -10), 1.9, 7.8, a_front, pink)
    if scared:
        pt.ellipse(hx + 4, hy - 1, 3.2, 3.2, "#ffffff")
        pt.ellipse(hx + 4.6, hy - 1, 1.5, 1.5, "#2a1a0c")
    else:
        pt.ellipse(hx + 4, hy - 1, 1.9, 1.9, "#2a1a0c")
    pt.ellipse(hx + 1.5, hy + 3.4, 2.5, 2.5, (249, 183, 204, 190))   # mejilla
    pt.ellipse(hx + 8.2, hy + 1.6, 1.7, 1.7, "#f06fa4")               # nariz
    pt.stroke(bezier((hx + 8, hy + 3.2), (hx + 6.5, hy + 5.4), (hx + 4.6, hy + 4.6)), 1.0, "#b96a82")
    out = Image.alpha_composite(sh.im, pt.im)
    return out.resize((FRAME_W, FRAME_H), Image.LANCZOS)


def frame_turtle(spec, pose, phase=0.0):
    """Tortuga verde: camina despacio; dormida o asustada se mete en el caparazón."""
    shell, dark, rim, skin, scute, size = spec["body"], spec["dark"], spec["belly"], spec["skin"], spec["scute"], spec["size"]
    walking = pose == "walk"
    tucked = pose in ("sleep", "scared")
    step = math.sin(phase) if walking else 0.0
    bob = abs(step) * 0.9
    pt = Painter(0, -bob, size)
    sh = Painter(0, 0, size)
    sh.ellipse(0, 1, 14, 5, (0, 0, 0, 46))
    dy = 4 if tucked else 0
    if not tucked:
        pt.ellipse(-8 - step * 1.6, -2.4, 3.6, 3, skin)
        pt.ellipse(9 + step * 1.6, -2.4, 3.6, 3, skin)
        pt.poly([(-15, -6), (-21, -4), (-15, -2)], skin)        # cola
        pt.ellipse(14, -9, 6, 4, skin)                            # cuello
        hb = step * 0.8
        pt.ellipse(19 + hb, -12, 5.6, 5.6, skin)                  # cabeza
        pt.ellipse(21.2 + hb, -13.4, 1.4, 1.4, "#17240f")
        pt.stroke(bezier((21.6 + hb, -9.6), (23.6 + hb, -8.6), (25 + hb, -9.6)), 1.0, "#2f5524")
    pt.ellipse(0, -4 + dy * 0.2, 16, 3.6, rim)
    dome = bezier((-15, -5 + dy * 0.2), (-15, -26 + dy), (0, -26 + dy), 12) + bezier((0, -26 + dy), (15, -26 + dy), (15, -5 + dy * 0.2), 12)
    pt.poly(dome, shell)
    y0 = -17 + dy * 0.7
    pt.poly([(-5, y0), (0, y0 - 4), (5, y0), (3, y0 + 5), (-3, y0 + 5)], scute)
    for pts in (((-12, y0 + 5), (-5, y0)), ((12, y0 + 5), (5, y0)), ((0, y0 - 4), (0, y0 - 8)), ((-3, y0 + 5), (-7, y0 + 9)), ((3, y0 + 5), (7, y0 + 9))):
        pt.stroke(list(pts), 1.2, dark)
    out = Image.alpha_composite(sh.im, pt.im)
    return out.resize((FRAME_W, FRAME_H), Image.LANCZOS)


def frame(spec, pose, phase=0.0):
    if spec["kind"] == "rabbit":
        return frame_rabbit(spec, pose, phase)
    if spec["kind"] == "turtle":
        return frame_turtle(spec, pose, phase)
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
