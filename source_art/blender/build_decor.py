"""
Decoración de la tienda (etapa 2) — 12 objetos, 2 orientaciones cada uno, con sombra de contacto propia.
Objetos de piso: orientación 'a' (frente hacia -Y) y 'b' (girado 90°). Objetos de pared: 'der' y 'izq'.
Cada sprite: PNG 2x recortado + ancla = píxel del punto del mundo (0,0,0) (esquina mínima de la huella).
Uso: python3 build_decor.py <salida> <menu.png>
"""
import sys, math, json, os
import bpy
import numpy as np
from mathutils import Vector
OUTDIR = sys.argv[1]; MENU = sys.argv[2]
SRC = open("/home/claude/kit/build_kit.py").read()
sys.argv = [sys.argv[0], OUTDIR, MENU]
exec(SRC[:SRC.index("room = build_room()")])
sc.eevee.taa_render_samples = 16
os.makedirs(f"{OUTDIR}/decor", exist_ok=True)

def cyl(name, loc, r, h, m, parent, verts=24, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc)
    o = bpy.context.active_object; o.name = name; o.parent = parent; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o
def sph(name, loc, r, m, parent, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=16, ring_count=8)
    o = bpy.context.active_object; o.name = name; o.scale = scale; o.parent = parent; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o
def C(n, hx, r=0.8, e=0): return mat("d_" + n, hx, r, e)

# ---------------- objetos (huella desde (0,0); frente hacia -Y) ----------------
def planta(r):
    cyl("Maceta", (0.25, 0.25, 0.17), 0.17, 0.34, C("terracota", "#c0663f"), r, r2=None)
    cyl("Borde", (0.25, 0.25, 0.33), 0.185, 0.04, C("terracota2", "#a9552f"), r)
    cyl("Tierra", (0.25, 0.25, 0.345), 0.16, 0.01, C("tierra", "#4a3424"), r)
    g1, g2 = C("hoja", "#3e8e4a"), C("hoja2", "#57ad63")
    for (x, y, z, s, m) in [(0.25, 0.25, 0.75, 0.2, g1), (0.16, 0.2, 0.62, 0.16, g2), (0.34, 0.3, 0.6, 0.15, g1),
                            (0.22, 0.34, 0.9, 0.13, g2), (0.3, 0.18, 0.95, 0.12, g1), (0.25, 0.25, 1.08, 0.1, g2)]:
        sph("Hoja", (x, y, z), s, m, r, (1, 1, 1.25))
    return (0.5, 0.5), "piso"

def lampara(r):
    cyl("Base", (0.25, 0.25, 0.02), 0.16, 0.04, C("metal", "#2b2f36", .4), r)
    cyl("Poste", (0.25, 0.25, 0.8), 0.018, 1.56, C("metal", "#2b2f36", .4), r)
    cyl("Pantalla", (0.25, 0.25, 1.6), 0.2, 0.32, C("pantalla", "#f3e3c3", .7, 0.8), r, r2=0.12)
    sph("Foco", (0.25, 0.25, 1.5), 0.05, C("foco", "#ffe9b0", .2, 8), r)
    return (0.5, 0.5), "piso"

def sillon(r):
    tela, tela2 = C("tela", "#2f6f7a"), C("tela2", "#275e68")
    cube("Base", (0.75, 0.48, 0.2), (1.5, 0.86, 0.3), tela2, 0.04, r)
    for x in (0.42, 1.08):
        cube("Cojin", (x, 0.42, 0.42), (0.62, 0.66, 0.14), tela, 0.05, r)
    cube("Respaldo", (0.75, 0.86, 0.6), (1.5, 0.2, 0.62), tela, 0.06, r)
    for x in (0.08, 1.42):
        cube("Brazo", (x, 0.48, 0.45), (0.16, 0.86, 0.36), tela2, 0.06, r)
    for x in (0.12, 1.38):
        for y in (0.12, 0.84):
            cube("Pata", (x, y, 0.03), (0.06, 0.06, 0.06), C("pata", "#3b2a1c"), 0.01, r)
    cube("CojinDeco", (1.15, 0.72, 0.62), (0.3, 0.12, 0.28), C("cojin", "#f5c542"), 0.05, r)
    return (1.5, 1.0), "piso"

def cafetera(r):
    mad = C("madera_c", "#b5773f")
    cube("Cubierta", (0.5, 0.25, 0.72), (1.0, 0.5, 0.05), mad, 0.01, r)
    for x in (0.06, 0.94):
        for y in (0.06, 0.44):
            cube("Pata", (x, y, 0.35), (0.05, 0.05, 0.7), C("madera_c2", "#8a5a2e"), 0.005, r)
    cube("Cafetera", (0.3, 0.27, 0.92), (0.26, 0.24, 0.36), C("negro", "#22252b", .35), 0.03, r)
    cube("Boquilla", (0.3, 0.14, 0.9), (0.12, 0.06, 0.08), C("metal2", "#9aa3ad", .3), 0.01, r)
    sph("Luz", (0.38, 0.145, 1.02), 0.012, C("luzroja", "#ff4d5e", .2, 6), r)
    for (x, c) in [(0.62, "#f4f4f4"), (0.78, "#e8649b")]:
        cyl("Taza", (x, 0.22, 0.79), 0.04, 0.09, C("taza" + c, c, .5), r)
    cube("Frasco", (0.72, 0.36, 0.84), (0.12, 0.12, 0.2), C("frasco", "#6b4a2f"), 0.02, r)
    return (1.0, 0.5), "piso"

def librero(r):
    mad, mad2 = C("lib", "#e9e4d8"), C("lib2", "#c9c2b2")
    cube("Lateral_I", (0.02, 0.2, 0.9), (0.04, 0.4, 1.8), mad, 0.005, r)
    cube("Lateral_D", (0.98, 0.2, 0.9), (0.04, 0.4, 1.8), mad, 0.005, r)
    cube("Fondo", (0.5, 0.39, 0.9), (1.0, 0.02, 1.8), mad2, 0, r)
    colors = ["#3a5a8b", "#8b3a3a", "#d1a646", "#2f6f7a", "#e8649b", "#4a4f5a", "#3e8e4a", "#c07a5a"]
    for k, z in enumerate((0.02, 0.45, 0.9, 1.35, 1.78)):
        cube("Repisa", (0.5, 0.2, z), (0.96, 0.38, 0.03), mad, 0.005, r)
        if z < 1.7:
            x = 0.08
            i = k
            while x < 0.85:
                w = 0.05 + (i % 3) * 0.015; h = 0.24 + (i % 4) * 0.03
                cube("Libro", (x + w / 2, 0.22, z + 0.015 + h / 2), (w, 0.26, h), C("libro" + colors[i % 8], colors[i % 8], .7), 0.004, r)
                x += w + 0.008; i += 1
                if i % 7 == 0: x += 0.12
    return (1.0, 0.5), "piso"

def tapete(r):
    cube("Tapete", (1.0, 0.75, 0.006), (2.0, 1.5, 0.012), C("tapete", "#5a6a8a", .95), 0.02, r)
    cube("Borde", (1.0, 0.75, 0.0125), (1.8, 1.3, 0.002), C("tapete2", "#e6e1d4", .95), 0, r)
    cube("Centro", (1.0, 0.75, 0.014), (1.7, 1.2, 0.002), C("tapete3", "#5a6a8a", .95), 0, r)
    for i in range(4):
        cube("Franja", (1.0, 0.36 + i * 0.26, 0.0155), (1.4, 0.06, 0.002), C("tapete4", "#d1a646", .95), 0, r)
    return (2.0, 1.5), "tapete"

def snacks(r):
    cube("Cuerpo", (0.45, 0.42, 0.9), (0.9, 0.8, 1.8), C("maq", "#b8433a", .5), 0.03, r)
    cube("Vidrio", (0.37, 0.015, 1.05), (0.62, 0.02, 1.25), C("vid", "#1d2533", .2, 0.3), 0.005, r)
    snack_cols = ["#f5c542", "#3ddc84", "#5aa9ff", "#e8649b", "#ff8f3d"]
    for row in range(5):
        z = 0.55 + row * 0.24
        for col in range(4):
            cube("Snack", (0.13 + col * 0.15, 0.04, z), (0.1, 0.04, 0.14), C("sn" + snack_cols[(row + col) % 5], snack_cols[(row + col) % 5], .5, 0.4), 0.01, r)
    cube("Panel", (0.79, 0.01, 1.2), (0.16, 0.02, 0.5), C("panel", "#2b2f36", .4), 0.005, r)
    for k in range(3):
        cube("Tecla", (0.79, 0.0, 1.32 - k * 0.1), (0.1, 0.01, 0.05), C("tecla", "#9aa3ad", .4, 0.5), 0, r)
    cube("Bandeja", (0.37, 0.01, 0.28), (0.62, 0.02, 0.2), C("band", "#111722", .4), 0.005, r)
    return (1.0, 1.0), "piso"

def consola(r):
    cube("Mueble", (0.75, 0.25, 0.24), (1.5, 0.46, 0.48), C("mueble", "#2b2f36", .6), 0.02, r)
    cube("Hueco", (0.75, 0.015, 0.2), (1.2, 0.02, 0.18), C("hueco", "#15181d", .8), 0, r)
    cube("Consola", (0.55, 0.06, 0.2), (0.34, 0.06, 0.06), C("cons", "#f4f4f4", .4), 0.01, r)
    sph("LedC", (0.71, 0.03, 0.2), 0.008, C("ledc", "#5aa9ff", .2, 6), r)
    cube("Pie_TV", (0.75, 0.3, 0.52), (0.3, 0.16, 0.04), C("pie", "#111722", .4), 0.01, r)
    cube("Cuello_TV", (0.75, 0.32, 0.6), (0.06, 0.04, 0.16), C("pie", "#111722", .4), 0, r)
    cube("TV", (0.75, 0.3, 0.98), (1.3, 0.05, 0.76), C("tvmarco", "#111722", .3), 0.01, r)
    cube("Pantalla", (0.75, 0.272, 0.98), (1.22, 0.01, 0.68), C("tvpant", "#1f3a63", .2, 1.2), 0, r)
    cube("Cielo", (0.75, 0.266, 1.15), (1.22, 0.004, 0.34), C("tvcielo", "#5aa9ff", .2, 1.4), 0, r)
    for (x, z, w, h, c) in [(0.4, 0.82, 0.3, 0.06, "#3ddc84"), (0.95, 0.9, 0.36, 0.06, "#3ddc84"), (0.62, 0.86, 0.06, 0.1, "#e8649b"), (1.1, 1.18, 0.08, 0.08, "#f5c542")]:
        cube("Juego", (x, 0.262, z), (w, 0.004, h), C("tj" + c, c, .3, 1.5), 0, r)
    for x in (1.15, 1.32):
        cube("Control", (x, 0.12, 0.5), (0.13, 0.08, 0.03), C("ctrl", "#4a4f5a", .4), 0.012, r)
    return (1.5, 0.5), "piso"

def acuario(r):
    cube("Mueble", (0.5, 0.25, 0.34), (1.0, 0.5, 0.68), C("muebleac", "#e9e4d8", .6), 0.015, r)
    cube("Agua", (0.5, 0.25, 0.97), (0.96, 0.42, 0.52), C("agua", "#4fa3c7", .1, 0.6), 0, r)
    for x in (0.02, 0.98):
        cube("Marco", (x, 0.25, 0.97), (0.03, 0.46, 0.56), C("marcoac", "#2b2f36", .4), 0, r)
    cube("MarcoSup", (0.5, 0.25, 1.24), (1.02, 0.46, 0.03), C("marcoac", "#2b2f36", .4), 0, r)
    cube("Arena", (0.5, 0.25, 0.73), (0.94, 0.4, 0.04), C("arena", "#e3cf9c", .9), 0, r)
    for (x, y, z, c) in [(0.3, 0.03, 0.95, "#ff8f3d"), (0.62, 0.03, 1.08, "#f5c542"), (0.75, 0.03, 0.88, "#ff8f3d"), (0.45, 0.03, 1.12, "#e8649b")]:
        sph("Pez", (x, y, z), 0.035, C("pez" + c, c, .4, 0.8), r, (1.5, 0.5, 1))
    for x in (0.18, 0.85):
        sph("Alga", (x, 0.2, 0.9), 0.06, C("alga", "#3e8e4a"), r, (0.6, 0.6, 2.2))
    return (1.0, 0.5), "piso"

def trofeo(r):
    cube("Pedestal", (0.25, 0.25, 0.45), (0.4, 0.4, 0.9), C("ped", "#2b2f36", .5), 0.02, r)
    cube("Placa", (0.25, 0.045, 0.6), (0.24, 0.01, 0.1), C("placa", "#d1a646", .3, 0.2), 0.005, r)
    oro = C("oro", "#e7b93a", .25, 0.15)
    cube("Base", (0.25, 0.25, 0.94), (0.2, 0.2, 0.08), C("baset", "#3b2a1c", .5), 0.01, r)
    cyl("Tallo", (0.25, 0.25, 1.04), 0.025, 0.12, oro, r)
    cyl("Copa", (0.25, 0.25, 1.2), 0.14, 0.22, oro, r, r2=0.07)
    for s in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.012, location=(0.25 + 0.15 * s, 0.25, 1.22), rotation=(math.radians(90), 0, 0))
        o = bpy.context.active_object; o.parent = r; o.data.materials.append(oro)
    sph("Estrella", (0.25, 0.25, 1.36), 0.04, C("estrella", "#fff1a8", .2, 3), r)
    return (0.5, 0.5), "piso"

def cuadro(r):
    cube("Marco", (0.45, 0.025, 1.6), (0.9, 0.05, 0.7), C("marcoq", "#2b2f36", .5), 0.01, r)
    cube("Lienzo", (0.45, -0.002, 1.6), (0.8, 0.01, 0.6), C("lienzo", "#f4efe4", .8), 0, r)
    for (x, z, w, h, c) in [(0.25, 1.68, 0.3, 0.34, "#e8649b"), (0.55, 1.5, 0.36, 0.22, "#2f6f7a"), (0.66, 1.75, 0.16, 0.16, "#f5c542"), (0.33, 1.42, 0.16, 0.1, "#3e5272")]:
        cube("Forma", (x, -0.009, z), (w, 0.004, h), C("f" + c, c, .7), 0, r)
    return (0.9, 0.05), "pared"

def neon(r):
    cube("Placa", (0.7, 0.02, 2.2), (1.4, 0.04, 0.5), C("placaneon", "#111722", .3), 0.02, r)
    tubo = C("tubo", "#ff6fb5", .2, 6)
    for (x, z, w, h) in [(0.7, 2.43, 1.32, 0.02), (0.7, 1.97, 1.32, 0.02), (0.05, 2.2, 0.02, 0.46), (1.35, 2.2, 0.02, 0.46)]:
        cube("Tubo", (x, -0.01, z), (w, 0.02, h), tubo, 0.005, r)
    return (1.4, 0.04), "pared"

# ---------------- PR B: helpers ----------------
def rod(name, p0, p1, rad, m, parent, verts=12):
    """Cilindro entre dos puntos (coordenadas locales del padre)."""
    p0, p1 = Vector(p0), Vector(p1); d = p1 - p0
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=rad, depth=d.length, location=(p0 + p1) / 2)
    o = bpy.context.active_object; o.name = name
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    o.parent = parent; o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = True
    return o

def ovoide(name, p0, p1, rad, m, parent):
    """Elipsoide alargado de p0 a p1 (los extremos llegan rad más allá de cada punto)."""
    p0, p1 = Vector(p0), Vector(p1); d = p1 - p0
    o = sph(name, (p0 + p1) / 2, rad, m, parent, (1, 1, (d.length / 2 + rad) / rad))
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return o

def plano(name, loc, w, h, m, parent):
    """Plano vertical w×h mirando hacia -Y (UV completo, para texturas)."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=(math.radians(90), 0, 0))
    o = bpy.context.active_object; o.name = name; o.scale = (w, h, 1)
    o.parent = parent; o.data.materials.append(m)
    return o

def img_mat(name, path, rough=0.85):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(path)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    return m

# Fuente pixel 3×5 para los títulos de los posters
_GLIFOS = {
    "A": ["010", "101", "111", "101", "101"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "G": ["011", "100", "101", "101", "011"],
    "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
    "L": ["100", "100", "100", "100", "111"], "N": ["101", "111", "111", "101", "101"],
    "O": ["111", "101", "101", "101", "111"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"],
    "Z": ["111", "001", "010", "100", "111"],
}

def _texto_pixel(px, x0, y0, texto, color):
    for i, ch in enumerate(texto):
        for fy, fila in enumerate(_GLIFOS[ch]):
            for fx, b in enumerate(fila):
                if b == "1": px[x0 + i * 4 + fx, y0 + fy] = color

def _hex(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

def _textura(nombre, w, h, dibujar, escala=8):
    """Dibuja una textura pixel-art en baja resolución y la escala sin suavizar."""
    from PIL import Image, ImageDraw
    os.makedirs(f"{OUTDIR}/_tex", exist_ok=True)
    img = Image.new("RGBA", (w, h)); dibujar(img, ImageDraw.Draw(img), img.load())
    path = f"{OUTDIR}/_tex/{nombre}.png"
    img.resize((w * escala, h * escala), Image.NEAREST).save(path)
    return path

def _poster_videojuegos(img, dr, px):
    dr.rectangle((0, 0, 47, 65), fill=_hex("#2b2557"))
    for (x, y) in [(4, 12), (41, 15), (8, 50), (40, 46), (24, 13), (14, 30), (36, 31), (44, 58), (3, 60)]:
        px[x, y] = _hex("#fce081")
    _texto_pixel(px, 2, 4, "VIDEOJUEGOS", _hex("#fce081"))
    # control genérico
    dr.rounded_rectangle((8, 30, 39, 46), radius=5, fill=_hex("#c9ccd6"))
    dr.rectangle((10, 44, 16, 52), fill=_hex("#c9ccd6")); dr.rectangle((31, 44, 37, 52), fill=_hex("#c9ccd6"))
    dr.rectangle((13, 35, 15, 41), fill=_hex("#3a3f4f")); dr.rectangle((11, 37, 17, 39), fill=_hex("#3a3f4f"))
    for (x, y, c) in [(31, 34, "#ff4d5e"), (34, 37, "#3ddc84"), (28, 37, "#5aa9ff"), (31, 40, "#f5c542")]:
        dr.rectangle((x, y, x + 1, y + 1), fill=_hex(c))
    dr.rectangle((21, 38, 26, 39), fill=_hex("#7a7f90"))
    # corazones pixel
    for cx in (15, 22, 29):
        for (dx, dy) in [(0, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (2, 1), (3, 1), (0, 2), (1, 2), (2, 2), (1, 3)]:
            px[cx + dx, 21 + dy] = _hex("#ff4d5e")

def _poster_naturaleza(img, dr, px):
    for y in range(66):
        t = y / 40
        c = tuple(int(a + (b - a) * min(t, 1)) for a, b in zip((143, 200, 236), (214, 238, 250))) + (255,)
        dr.line((0, y, 47, y), fill=c)
    dr.ellipse((33, 6, 41, 14), fill=_hex("#fce081"))
    dr.ellipse((5, 9, 15, 14), fill=_hex("#ffffff")); dr.ellipse((10, 7, 20, 13), fill=_hex("#ffffff"))
    dr.polygon([(0, 36), (12, 20), (22, 33), (32, 18), (47, 34), (47, 40), (0, 40)], fill=_hex("#7c97b8"))
    dr.polygon([(26, 23), (32, 18), (36, 22), (32, 21)], fill=_hex("#f4f4f4"))
    dr.rectangle((0, 38, 47, 53), fill=_hex("#6fae4f"))
    dr.ellipse((10, 42, 38, 50), fill=_hex("#5aa9d6"))
    for (x, h) in [(3, 13), (8, 10), (40, 12), (44, 9)]:
        dr.polygon([(x, 44 - h), (x - 3, 44), (x + 3, 44)], fill=_hex("#2f6b45"))
        dr.rectangle((x, 44, x, 46), fill=_hex("#6b4a2f"))
    for (x, y, c) in [(6, 50, "#e8649b"), (14, 52, "#fce081"), (36, 52, "#e8649b"), (42, 49, "#ffffff")]:
        px[x, y] = _hex(c)
    dr.rectangle((0, 54, 47, 65), fill=_hex("#2d5a3a"))
    _texto_pixel(px, 4, 57, "NATURALEZA", _hex("#fce081"))

def _pantalla_codigo(img, dr, px):
    dr.rectangle((0, 0, 63, 35), fill=_hex("#1b2333"))
    dr.rectangle((0, 0, 63, 2), fill=_hex("#2a3550"))
    dr.rectangle((0, 3, 4, 35), fill=_hex("#151c29"))
    cols = ["#5aa9ff", "#3ddc84", "#e8649b", "#f5c542", "#c5adcc", "#89c7e7"]
    largos = [22, 30, 14, 36, 26, 18, 40, 12, 28, 20, 34, 16]
    for i, l in enumerate(largos):
        y = 5 + i * 2 + (i // 4)
        if y > 33: break
        ind = 7 + (i % 3) * 3
        dr.line((ind, y, ind + l // 2, y), fill=_hex(cols[i % len(cols)]))
        dr.line((ind + l // 2 + 2, y, min(ind + l, 60), y), fill=_hex(cols[(i + 2) % len(cols)]))

def _pantalla_monitoreo(img, dr, px):
    dr.rectangle((0, 0, 63, 35), fill=_hex("#0b111c"))
    dr.rectangle((0, 0, 63, 2), fill=_hex("#16233a"))
    dr.rectangle((2, 5, 38, 22), outline=_hex("#223049"))
    pts = [(3, 19), (8, 16), (13, 17), (18, 12), (23, 14), (28, 9), (33, 11), (37, 7)]
    dr.line(pts, fill=_hex("#3ddc84"))
    for i, (h, c) in enumerate([(12, "#5aa9ff"), (8, "#5aa9ff"), (14, "#f5c542"), (6, "#5aa9ff")]):
        dr.rectangle((43 + i * 5, 22 - h, 45 + i * 5, 22), fill=_hex(c))
    for i, (w, c) in enumerate([(40, "#3ddc84"), (28, "#f5c542"), (50, "#3ddc84")]):
        y = 26 + i * 3
        dr.rectangle((2, y, 61, y + 1), fill=_hex("#16233a"))
        dr.rectangle((2, y, 2 + w, y + 1), fill=_hex(c))

# ---------------- PR B: mobiliario nuevo (feedback de Jaq) ----------------
def tapete_redondo(r):
    tela, tela2 = C("tapred", "#6b4f8a", .95), C("tapred2", "#e6e1d4", .95)
    cyl("Base", (0.5, 0.5, 0.006), 0.5, 0.012, tela, r, verts=32)
    cyl("Borde", (0.5, 0.5, 0.013), 0.42, 0.002, tela2, r, verts=32)
    cyl("Centro", (0.5, 0.5, 0.0145), 0.3, 0.002, tela, r, verts=32)
    return (1.0, 1.0), "tapete"

def tapete_estampado(r):
    base, acc = C("tapest", "#2f6f7a", .95), C("tapest2", "#f5c542", .95)
    cube("Base", (0.75, 0.75, 0.006), (1.5, 1.5, 0.012), base, 0.02, r)
    cube("Borde", (0.75, 0.75, 0.0125), (1.3, 1.3, 0.002), C("tapest3", "#e6e1d4", .95), 0, r)
    for i in range(5):
        cube("Franja", (0.75, 0.2 + i * 0.3, 0.0155), (1.1, 0.06, 0.002), acc, 0, r)
    return (1.5, 1.5), "tapete"

def sillon_l(r):
    # Sillón esquinero tipo sectional (referencia de Jaq): respaldo en los dos lados del fondo
    # (y = máx y x = 0), brazos en los dos extremos abiertos, cojines de asiento y de respaldo.
    tela, cojin = C("sl_tela", "#33476b", .85), C("sl_cojin", "#3e5682", .85)
    base_m, pata = C("sl_base", "#28385a", .85), C("sl_pata", "#1c1f26", .5)
    W, D, d, bt, arm = 2.0, 1.5, 0.85, 0.2, 0.18
    # las bases quedan 2 cm adentro de los brazos para que sus caras no se encimen
    cube("Base_largo", ((W - 0.02) / 2, D - (d - 0.02) / 2, 0.19), (W - 0.02, d - 0.02, 0.22), base_m, 0.03, r)
    cube("Base_corto", ((d - 0.02) / 2, (D - d) / 2 + 0.02, 0.19), (d - 0.02, D - d, 0.22), base_m, 0.03, r)
    cube("Respaldo_fondo", (W / 2, D - bt / 2, 0.45), (W, bt, 0.74), tela, 0.05, r)
    cube("Respaldo_lado", (bt / 2, (D - bt) / 2, 0.45), (bt, D - bt, 0.74), tela, 0.05, r)
    cube("Brazo_der", (W - arm / 2, (D - d + D - bt) / 2, 0.35), (arm, d - bt, 0.54), tela, 0.05, r)
    cube("Brazo_frente", ((bt + d) / 2, arm / 2, 0.35), (d - bt, arm, 0.54), tela, 0.05, r)
    g = 0.014
    for (x0, x1, y0, y1) in [(bt, d, D - d, D - bt), (d, 1.335, D - d, D - bt), (1.335, W - arm, D - d, D - bt), (bt, d, arm, D - d)]:
        cube("Cojin", ((x0 + x1) / 2, (y0 + y1) / 2, 0.37), (x1 - x0 - g, y1 - y0 - g, 0.14), cojin, 0.045, r)
    tb = 0.16
    for (x0, x1) in [(bt + tb, d), (d, 1.335), (1.335, W - arm)]:
        cube("CojinRespaldo", ((x0 + x1) / 2, D - bt - tb / 2, 0.61), (x1 - x0 - g, tb, 0.34), cojin, 0.06, r)
    for (y0, y1) in [(arm, D - d), (D - d, D - bt - tb)]:
        cube("CojinRespaldo", (bt + tb / 2, (y0 + y1) / 2, 0.61), (tb, y1 - y0 - g, 0.34), cojin, 0.06, r)
    for (x, y) in [(0.06, 0.06), (d - 0.06, 0.06), (W - 0.06, D - d + 0.06), (W - 0.06, D - 0.06), (0.06, D - 0.06)]:
        cube("Pata", (x, y, 0.04), (0.05, 0.05, 0.08), pata, 0.01, r)
    return (2.0, 1.5), "piso"

def mesa_auxiliar(r):
    mad = C("mesaux", "#8a5a2e")
    cyl("Base", (0.25, 0.25, 0.02), 0.14, 0.04, mad, r)
    cyl("Pata", (0.25, 0.25, 0.26), 0.02, 0.48, mad, r)
    cyl("Tapa", (0.25, 0.25, 0.52), 0.2, 0.04, C("mesaux2", "#b5773f"), r)
    return (0.5, 0.5), "piso"

def estanteria(r):
    mad, mad2 = C("estan", "#c9c2b2"), C("estan2", "#a69c86")
    cube("Lateral_I", (0.02, 0.2, 0.75), (0.04, 0.4, 1.5), mad, 0.005, r)
    cube("Lateral_D", (1.48, 0.2, 0.75), (0.04, 0.4, 1.5), mad, 0.005, r)
    for z in (0.02, 0.5, 1.0, 1.48):
        cube("Repisa", (0.75, 0.2, z), (1.46, 0.38, 0.03), mad2, 0.005, r)
    colores = ["#5aa9ff", "#f5c542", "#3ddc84", "#e8649b"]
    for i, x in enumerate((0.2, 0.55, 0.9, 1.25)):
        cube("Objeto", (x, 0.2, 0.74 + 0.26 * (i % 2)), (0.16, 0.16, 0.22), C("estob" + colores[i], colores[i], .6), 0.01, r)
    return (1.5, 0.5), "piso"

def ventana_1(r):
    marco, vidrio = C("vent1m", "#e9e4d8", .6), C("vent1v", "#a9d4e8", .15, 0.3)
    cube("Marco", (0.45, 0.025, 1.3), (0.9, 0.05, 1.1), marco, 0.01, r)
    cube("Vidrio", (0.45, -0.002, 1.3), (0.78, 0.01, 0.95), vidrio, 0, r)
    cube("Cruz_v", (0.45, -0.004, 1.3), (0.04, 0.012, 0.95), marco, 0, r)
    cube("Cruz_h", (0.45, -0.004, 1.3), (0.78, 0.012, 0.04), marco, 0, r)
    cube("Repisa", (0.45, 0.06, 0.74), (0.96, 0.12, 0.04), marco, 0.005, r)
    return (0.9, 0.05), "pared"

def ventana_2(r):
    # Ventana de madera de 2 hojas con cortinas recogidas y barra con argollas (referencia de Jaq).
    mad, mad2 = C("v2_mad", "#d39a5e", .6), C("v2_mad2", "#b9824b", .6)
    vidrio = C("v2_vidrio", "#b3d8ee", .1, 0.2)
    tela, tela2 = C("v2_tela", "#bcae99", .9), C("v2_tela2", "#a99b86", .9)
    met = C("v2_barra", "#5b4a3a", .4)
    cube("Vidrio", (0.45, 0.08, 1.43), (0.6, 0.006, 1.08), vidrio, 0, r)
    cube("Marco_sup", (0.45, 0.065, 1.975), (0.66, 0.05, 0.05), mad, 0.006, r)
    cube("Repisa", (0.45, 0.055, 0.87), (0.72, 0.07, 0.05), mad2, 0.006, r)
    for x in (0.145, 0.755):
        cube("Marco_lado", (x, 0.065, 1.425), (0.05, 0.05, 1.15), mad, 0.006, r)
    cube("Parteluz", (0.45, 0.07, 1.425), (0.035, 0.04, 1.06), mad, 0.004, r)
    for x0, x1 in ((0.17, 0.4325), (0.4675, 0.73)):
        cube("Hoja_inf", ((x0 + x1) / 2, 0.072, 0.925), (x1 - x0, 0.03, 0.035), mad2, 0.003, r)
    rod("Barra", (0.02, 0.03, 2.1), (0.88, 0.03, 2.1), 0.011, met, r)
    for x in (0.02, 0.88):
        sph("Remate", (x, 0.03, 2.1), 0.02, met, r)
        cube("Soporte", (x + (0.03 if x < 0.45 else -0.03), 0.06, 2.1), (0.012, 0.06, 0.012), met, 0, r)
    # cortinas: pliegues que se juntan en el amarre (forma de reloj de arena)
    for lado in (0, 1):
        def X(x): return x if lado == 0 else 0.9 - x
        arriba = [0.03, 0.065, 0.10, 0.135, 0.17, 0.205]
        amarre = [0.085, 0.098, 0.111, 0.124, 0.137, 0.15]
        abajo = [0.06, 0.088, 0.116, 0.144, 0.172, 0.2]
        for i, (a, b, c) in enumerate(zip(arriba, amarre, abajo)):
            m = tela if i % 2 == 0 else tela2
            y = 0.024 if i % 2 == 0 else 0.036
            rod("Pliegue", (X(a), y, 2.08), (X(b), y, 1.32), 0.02, m, r, 8)
            rod("Pliegue", (X(b), y, 1.32), (X(c), y, 0.8), 0.02, m, r, 8)
            sph("Nudo", (X(b), y, 1.32), 0.02, m, r)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.017, minor_radius=0.004, location=(X(a), 0.03, 2.1), rotation=(0, math.radians(90), 0))
            o = bpy.context.active_object; o.parent = r; o.data.materials.append(met)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.05, minor_radius=0.009, location=(X(0.118), 0.03, 1.32))
        o = bpy.context.active_object; o.scale = (1, 0.45, 1); o.parent = r; o.data.materials.append(C("v2_amarre", "#8c7a62", .8))
    return (0.9, 0.09), "pared"

def cuadro_2(r):
    marco, lienzo = C("cq2m", "#3b2a1c", .6), C("cq2l", "#f0e6d2", .8)
    cube("Marco", (0.45, 0.025, 1.6), (0.9, 0.05, 0.7), marco, 0.01, r)
    cube("Lienzo", (0.45, -0.002, 1.6), (0.8, 0.01, 0.6), lienzo, 0, r)
    for (x, z, rad, c) in [(0.3, 1.75, 0.1, "#5aa9ff"), (0.6, 1.55, 0.13, "#f5c542"), (0.5, 1.7, 0.07, "#3ddc84")]:
        sph("Forma", (x, -0.009, z), rad, C("cq2f" + c, c, .5), r, (1, 0.2, 1))
    return (0.9, 0.05), "pared"

def posters(r):
    # Dos posters con ilustración pixel-art: videojuegos y naturaleza (referencia de Jaq).
    borde = C("post_borde", "#f4f1ea", .9)
    for (x, z, dib, nom) in [(0.2, 1.56, _poster_videojuegos, "poster_videojuegos"), (0.6, 1.6, _poster_naturaleza, "poster_naturaleza")]:
        cube("Hoja", (x, 0.014, z), (0.36, 0.006, 0.5), borde, 0, r)
        plano("Arte", (x, 0.0105, z), 0.33, 0.47, img_mat("m_" + nom, _textura(nom, 48, 66, dib), .9), r)
    return (0.8, 0.02), "pared"

def planta_2(r):
    cyl("Maceta", (0.25, 0.25, 0.15), 0.15, 0.3, C("cact_m", "#c0663f"), r)
    g = C("cact_g", "#3e8e4a")
    cyl("Tallo1", (0.25, 0.25, 0.55), 0.06, 0.5, g, r)
    cyl("Tallo2", (0.15, 0.28, 0.45), 0.04, 0.3, g, r)
    cyl("Tallo3", (0.35, 0.22, 0.5), 0.045, 0.35, g, r)
    sph("Flor", (0.25, 0.25, 0.82), 0.04, C("cact_f", "#e8649b", .4, 2), r)
    return (0.5, 0.5), "piso"

def planta_3(r):
    cyl("Maceta", (0.25, 0.25, 0.15), 0.15, 0.3, C("fern_m", "#8a5a2e"), r)
    g1, g2 = C("fern_g", "#57ad63"), C("fern_g2", "#3e8e4a")
    for (x, y, z, s, m) in [(0.1, 0.25, 0.5, 0.22, g1), (0.4, 0.25, 0.5, 0.22, g2), (0.25, 0.1, 0.45, 0.2, g1),
                             (0.25, 0.4, 0.45, 0.2, g2), (0.25, 0.25, 0.75, 0.16, g1)]:
        sph("Hoja", (x, y, z), s, m, r, (1, 1, 0.6))
    return (0.5, 0.5), "piso"

def planta_4(r):
    cyl("Maceta", (0.25, 0.25, 0.15), 0.14, 0.3, C("flor_m", "#e9e4d8"), r)
    g = C("flor_g", "#3e8e4a")
    cyl("Tallo", (0.25, 0.25, 0.55), 0.015, 0.5, g, r)
    for (x, y, z, c) in [(0.18, 0.22, 0.78, "#e8649b"), (0.32, 0.28, 0.82, "#f5c542"), (0.25, 0.25, 0.9, "#5aa9ff")]:
        sph("Flor", (x, y, z), 0.07, C("flor_f" + c, c, .5), r, (1, 1, 0.7))
    for z in (0.45, 0.6):
        sph("Hoja", (0.25, 0.25, z), 0.1, g, r, (1.3, 0.3, 1))
    return (0.5, 0.5), "piso"

def florero(r):
    vidrio = C("flov", "#a9d4e8", .2, 0.6)
    cyl("Base", (0.25, 0.25, 0.04), 0.09, 0.03, vidrio, r)
    cyl("Cuerpo", (0.25, 0.25, 0.17), 0.1, 0.2, vidrio, r, r2=0.06)
    cyl("Cuello", (0.25, 0.25, 0.3), 0.035, 0.08, vidrio, r)
    cyl("Boca", (0.25, 0.25, 0.345), 0.045, 0.015, vidrio, r)
    g = C("flog", "#3e8e4a")
    for (x, y, h) in [(0.22, 0.24, 0.26), (0.28, 0.26, 0.3), (0.25, 0.22, 0.22)]:
        cyl("Tallo", (x, y, 0.35 + h / 2), 0.006, h, g, r)
    for (x, y, z, c) in [(0.2, 0.22, 0.56, "#e8649b"), (0.3, 0.27, 0.6, "#f5c542"), (0.25, 0.2, 0.52, "#5aa9ff")]:
        sph("Flor", (x, y, z), 0.05, C("flof" + c, c, .5), r)
    return (0.5, 0.5), "piso"

def osito(r):
    # Osito de peluche sentado con las piernas al frente (referencia de Jaq).
    pelo, claro, osc = C("os_pelo", "#9b6236", .9), C("os_claro", "#dcaa72", .9), C("os_osc", "#2a1b14", .3)
    sph("Cuerpo", (0.25, 0.27, 0.155), 0.12, pelo, r, (1, 0.9, 1.15))
    sph("Panza", (0.25, 0.18, 0.145), 0.075, claro, r, (1, 0.45, 1.15))
    for s in (-1, 1):
        ovoide("Pierna", (0.25 + s * 0.05, 0.25, 0.075), (0.25 + s * 0.085, 0.085, 0.06), 0.055, pelo, r)
        sph("Planta", (0.25 + s * 0.093, 0.032, 0.062), 0.036, claro, r, (1, 0.35, 1))
        ovoide("Brazo", (0.25 + s * 0.085, 0.245, 0.255), (0.25 + s * 0.135, 0.185, 0.125), 0.045, pelo, r)
    sph("Cabeza", (0.25, 0.245, 0.36), 0.11, pelo, r)
    sph("Hocico", (0.25, 0.15, 0.335), 0.052, claro, r, (1.1, 0.75, 0.82))
    sph("Nariz", (0.25, 0.112, 0.355), 0.02, osc, r, (1.2, 0.8, 0.8))
    for s in (-1, 1):
        sph("Ojo", (0.25 + s * 0.042, 0.15, 0.385), 0.014, osc, r)
        sph("Oreja", (0.25 + s * 0.085, 0.265, 0.445), 0.045, pelo, r, (1, 0.65, 1))
        sph("OrejaIn", (0.25 + s * 0.085, 0.24, 0.44), 0.027, claro, r, (1, 0.45, 1))
    return (0.5, 0.5), "piso"

def balon_voli(r):
    # Balón de voleibol de paneles: esfera hecha de un cubo subdividido, 3 franjas por cara.
    rad = 0.105
    mats = [C("bv_blanco", "#f5f3ea", .45), C("bv_amarillo", "#f2c21b", .45), C("bv_azul", "#1f5fb8", .45)]
    patron = {0: (1, 0, 2), 1: (2, 1, 0), 2: (0, 2, 1)}
    me = bpy.data.meshes.new("Balon"); o = bpy.data.objects.new("Balon", me); sc.collection.objects.link(o)
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=11, use_grid_fill=True)
    for f in bm.faces:
        c = f.calc_center_median()
        ax = max(range(3), key=lambda i: abs(c[i]))
        sec = {0: 2, 1: 0, 2: 1}[ax]
        f.material_index = patron[ax][min(2, int((c[sec] + 1) * 1.5))]
    for v in bm.verts: v.co = v.co.normalized() * rad
    bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    for p in me.polygons: p.use_smooth = True
    o.location = (0.25, 0.25, rad); o.rotation_euler = (math.radians(20), math.radians(-15), math.radians(30)); o.parent = r
    return (0.5, 0.5), "piso"

def colocador(r):
    # Perchero de madera con base en cruz, ganchos curvos, sombrero y mochila (referencia de Jaq).
    mad, mad2 = C("col_mad", "#b07a45", .7), C("col_mad2", "#946336", .7)
    cx, cy = 0.25, 0.25
    cube("Pie", (cx, cy, 0.025), (0.46, 0.06, 0.05), mad2, 0.01, r)
    cube("Pie", (cx, cy, 0.025), (0.06, 0.46, 0.05), mad2, 0.01, r)
    cube("Poste", (cx, cy, 0.9), (0.05, 0.05, 1.7), mad, 0.008, r)
    sph("Remate", (cx, cy, 1.77), 0.034, mad, r)
    def gancho(a, z, largo):
        u = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        p0 = Vector((cx, cy, z)) + u * 0.02; p1 = Vector((cx, cy, z + 0.03)) + u * largo; p2 = p1 + Vector((0, 0, 0.08)) + u * 0.015
        rod("Gancho", p0, p1, 0.012, mad, r, 8); rod("Gancho", p1, p2, 0.012, mad, r, 8)
        sph("Codo", p1, 0.012, mad, r); sph("Punta", p2, 0.016, mad, r)
        return p2, u
    puntas = {}
    for a in (0, 90, 180, 270): puntas[("arriba", a)] = gancho(a, 1.56, 0.13)
    for a in (45, 135, 225, 315): puntas[("abajo", a)] = gancho(a, 1.26, 0.11)
    # sombrero colgado del gancho de arriba que apunta a +X
    tip, u = puntas[("arriba", 0)]
    eje = (u * math.cos(math.radians(12)) + Vector((0, 0, math.sin(math.radians(12))))).normalized()
    s = group("Sombrero"); s.parent = r
    s.location = tip - eje * 0.08; s.rotation_euler = eje.to_track_quat('Z', 'Y').to_euler()
    paja, cinta = C("col_paja", "#c9a36a", .85), C("col_cinta", "#5a3a24", .7)
    cyl("Ala", (0, 0, 0.006), 0.125, 0.012, paja, s, 32)
    cyl("Copa", (0, 0, 0.05), 0.068, 0.085, paja, s, 24, r2=0.06)
    cyl("Cinta", (0, 0, 0.024), 0.07, 0.022, cinta, s, 24)
    # mochila colgada del gancho de abajo que apunta hacia el frente
    tip, u = puntas[("abajo", 315)]
    mo = group("Mochila"); mo.parent = r; mo.location = tip; mo.rotation_euler = (0, 0, math.radians(315 + 90))
    tela, tela2, cierre = C("col_moch", "#a7604a", .8), C("col_moch2", "#8a4c3a", .8), C("col_cierre", "#e9dccb", .6)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.03, minor_radius=0.007, location=(0, 0, -0.012), rotation=(math.radians(90), 0, 0))
    o = bpy.context.active_object; o.parent = mo; o.data.materials.append(tela2)
    cube("Cuerpo", (0, 0, -0.18), (0.22, 0.11, 0.27), tela, 0.045, mo)
    cube("Tapa", (0, -0.035, -0.085), (0.2, 0.06, 0.08), tela2, 0.025, mo)
    cube("Bolsa", (0, -0.065, -0.225), (0.15, 0.03, 0.11), tela2, 0.015, mo)
    cube("Cierre", (0, -0.081, -0.19), (0.12, 0.004, 0.006), cierre, 0, mo)
    for s_ in (-1, 1):
        cube("Tirante", (s_ * 0.065, 0.06, -0.17), (0.03, 0.015, 0.22), tela2, 0.006, mo)
    return (0.5, 0.5), "piso"

def lampara_2(r):
    # Lámpara de pie de trípode: tres patas de madera y pantalla de tambor encendida.
    mad, met = C("lt_mad", "#b98a5a", .6), C("lt_met", "#2b2f36", .4)
    tela, foco = C("lt_tela", "#ecdcb8", .8, 0.12), C("lt_foco", "#ffe9b0", .2, 8)
    apex = Vector((0.25, 0.25, 1.16))
    for a in (90, 210, 330):
        pie = Vector((0.25 + 0.2 * math.cos(math.radians(a)), 0.25 + 0.2 * math.sin(math.radians(a)), 0.012))
        rod("Pata", pie, apex, 0.016, mad, r, 10)
        sph("Regaton", pie, 0.018, met, r)
    cyl("Union", (0.25, 0.25, 1.17), 0.03, 0.06, met, r)
    cyl("Vastago", (0.25, 0.25, 1.27), 0.012, 0.16, met, r)
    sph("Foco", (0.25, 0.25, 1.36), 0.045, foco, r)
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.19, depth=0.26, location=(0.25, 0.25, 1.37), end_fill_type='NOTHING')
    o = bpy.context.active_object; o.name = "Pantalla"; o.parent = r; o.data.materials.append(tela)
    for p in o.data.polygons: p.use_smooth = True
    return (0.5, 0.5), "piso"

def computadora_doble(r):
    # Estación de trabajo: escritorio blanco (como el de la nota de Jaq), 2 monitores encendidos,
    # teclado, mouse, taza roja, CPU y silla.
    blanco, gris = C("cd_blanco", "#eeeae2", .7), C("cd_gris", "#cfcac0", .6)
    osc, marco = C("cd_osc", "#2b2f36", .5), C("cd_marco", "#1d2129", .4)
    cube("Cubierta", (0.75, 0.68, 0.74), (1.4, 0.6, 0.04), blanco, 0.006, r)
    for (x, y) in [(0.09, 0.42), (1.41, 0.42), (0.09, 0.94), (1.41, 0.94)]:
        cube("Pata", (x, y, 0.36), (0.045, 0.045, 0.72), gris, 0.004, r)
    for (nom, x, ang, dib) in [("MonitorIzq", 0.45, 10, _pantalla_codigo), ("MonitorDer", 1.05, -10, _pantalla_monitoreo)]:
        g = group(nom); g.parent = r; g.location = (x, 0.72, 0.76); g.rotation_euler = (0, 0, math.radians(ang))
        cube("Base", (0, 0.04, 0.008), (0.22, 0.15, 0.016), osc, 0.006, g)
        cube("Cuello", (0, 0.07, 0.15), (0.05, 0.025, 0.27), osc, 0.005, g)
        cube("Marco", (0, 0.045, 0.36), (0.56, 0.03, 0.33), marco, 0.008, g)
        plano("Pantalla", (0, 0.0285, 0.365), 0.53, 0.30, screen_mat(_textura("pantalla_" + nom, 64, 36, dib, 6)), g)
    cube("Teclado", (0.75, 0.52, 0.772), (0.42, 0.13, 0.024), C("cd_tec", "#3b4252", .5), 0.006, r)
    cube("Teclas", (0.75, 0.515, 0.786), (0.39, 0.1, 0.006), C("cd_tec2", "#5b6475", .5), 0, r)
    cube("Tapete", (1.12, 0.53, 0.762), (0.22, 0.18, 0.004), osc, 0, r)
    cube("Mouse", (1.12, 0.52, 0.778), (0.055, 0.09, 0.03), C("cd_mouse", "#e6e6e6", .4), 0.02, r)
    roja = C("cd_taza", "#d64545", .5)
    cyl("Taza", (0.24, 0.53, 0.81), 0.035, 0.1, roja, r)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.025, minor_radius=0.007, location=(0.28, 0.53, 0.81), rotation=(math.radians(90), 0, 0))
    o = bpy.context.active_object; o.parent = r; o.data.materials.append(roja)
    cube("CPU", (1.24, 0.71, 0.235), (0.2, 0.42, 0.45), C("cd_cpu", "#1f232b", .45), 0.01, r)
    cube("LuzCPU", (1.3, 0.497, 0.28), (0.012, 0.006, 0.3), C("cd_led", "#5aa9ff", .2, 3), 0, r)
    sph("Encendido", (1.19, 0.497, 0.42), 0.012, C("cd_led2", "#3ddc84", .2, 4), r)
    # silla de oficina girada un poco hacia la cámara
    ch = group("Silla"); ch.parent = r; ch.location = (0.72, 0.3, 0); ch.rotation_euler = (0, 0, math.radians(-20))
    tapiz, ruedas = C("cd_tapiz", "#353a44", .8), C("cd_ruedas", "#16181d", .4)
    for k in range(5):
        a = math.radians(90 + k * 72); fin = Vector((0.23 * math.cos(a), 0.23 * math.sin(a), 0.055))
        rod("PataSilla", (0, 0, 0.075), fin, 0.016, ruedas, ch, 8)
        sph("Rueda", fin - Vector((0, 0, 0.03)), 0.024, ruedas, ch)
    cyl("Piston", (0, 0, 0.24), 0.022, 0.32, C("cd_piston", "#7a808c", .3), ch)
    cube("Asiento", (0, 0.02, 0.43), (0.46, 0.44, 0.08), tapiz, 0.035, ch)
    cube("Soporte", (0, -0.2, 0.5), (0.06, 0.05, 0.16), ruedas, 0.008, ch)
    resp = cube("Respaldo", (0, -0.21, 0.75), (0.44, 0.07, 0.5), tapiz, 0.04, ch)
    resp.rotation_euler = (math.radians(-8), 0, 0)
    return (1.5, 1.0), "piso"

CATALOGO = [
  ("planta", "Planta", planta, 150), ("lampara", "Lámpara de pie", lampara, 200), ("sillon", "Sillón", sillon, 600),
  ("cafetera", "Mesita con cafetera", cafetera, 350), ("librero", "Librero", librero, 450), ("tapete", "Tapete", tapete, 250),
  ("snacks", "Máquina de snacks", snacks, 700), ("consola", "Consola de videojuegos", consola, 900), ("acuario", "Acuario", acuario, 800),
  ("trofeo", "Trofeo Scale-up", trofeo, 0), ("cuadro", "Cuadro", cuadro, 300), ("neon", "Letrero de neón (nombre de tu empresa)", neon, 500),
  # PR B — mobiliario nuevo (feedback de Jaq)
  ("tapete_redondo", "Tapete redondo", tapete_redondo, 180), ("tapete_estampado", "Tapete estampado", tapete_estampado, 220),
  ("sillon_l", "Sillón en forma de L", sillon_l, 950), ("mesa_auxiliar", "Mesa auxiliar", mesa_auxiliar, 180),
  ("estanteria", "Estantería", estanteria, 500), ("ventana_1", "Ventana — prototipo 1", ventana_1, 320),
  ("ventana_2", "Ventana — prototipo 2", ventana_2, 320), ("cuadro_2", "Cuadro", cuadro_2, 300),
  ("posters", "Posters", posters, 150), ("planta_2", "Planta — diseño 2", planta_2, 150),
  ("planta_3", "Planta — diseño 3", planta_3, 150), ("planta_4", "Planta — diseño 4", planta_4, 150),
  ("florero", "Florero", florero, 100), ("osito", "Osito", osito, 80), ("balon_voli", "Balón de voli", balon_voli, 60),
  ("colocador", "Colocador", colocador, 220), ("lampara_2", "Lámpara — diseño 2", lampara_2, 210),
  ("computadora_doble", "Computadora (doble monitor)", computadora_doble, 1500),
]

# ---------------- cámara y render ----------------
cam_data = bpy.data.cameras.new("IsoCam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("IsoCam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
cam.rotation_euler = (math.radians(60), 0, math.radians(45)); bpy.context.view_layer.update()
R = cam.matrix_world.to_3x3()
RIGHT, UP, FWD = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
PPM2 = PPM * 2
catch_m = bpy.data.materials.new("catcher"); catch_m.use_nodes = True
catch_m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.8, 0.8, 0.8, 1)
catch_m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0

def kids(r): return [r] + list(r.children_recursive)
def render_to(path):
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
    return np.array(bpy.data.images.load(path, check_existing=False).pixels[:]).reshape(sc.render.resolution_y, sc.render.resolution_x, 4)[::-1]

from PIL import Image
meta = {"celda_m": 0.5, "nota": "sprite en (pixel_mundo(esquina mínima de la huella) - ancla), lienzo 2x; para pared, la huella x es a lo largo del muro.", "objetos": []}
_ONLY = [x for x in os.environ.get("ONLY", "").split(",") if x]
for oid, nombre, fn, precio in CATALOGO:
    if _ONLY and oid not in _ONLY: continue
    root = group("D_" + oid)
    (fw, fd), tipo = fn(root)
    entry = {"id": oid, "nombre": nombre, "precio": precio, "tipo": tipo, "orientaciones": {}}
    if tipo == "pared":
        orients = [("der", 0, (0, 0, 0)), ("izq", 90, (fd, 0, 0))]  # izq: frente hacia +X, respaldo pegado a x=0
    else:
        orients = [("a", 0, (0, 0, 0)), ("b", 90, (fd, 0, 0))]
    for tag, rot, loc in orients:
        root.rotation_euler = (0, 0, math.radians(rot)); root.location = loc
        bpy.context.view_layer.update()
        objs = [o for o in kids(root) if o.type == "MESH"]
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        # catcher: piso (o pared detrás)
        if tipo == "pared":
            if tag == "der":
                bpy.ops.mesh.primitive_plane_add(size=6, location=(fw / 2, fd + 0.001, 1.6), rotation=(math.radians(90), 0, 0))
            else:
                bpy.ops.mesh.primitive_plane_add(size=6, location=(-0.001, fw / 2, 1.6), rotation=(0, math.radians(90), 0))
        else:
            bpy.ops.mesh.primitive_plane_add(size=8, location=(1, 1, -0.0005))
        catcher = bpy.context.active_object; catcher.data.materials.append(catch_m)
        xs = [p.dot(RIGHT) for p in pts]; ys = [p.dot(UP) for p in pts]
        # margen para que quepa la sombra
        m = 0.9
        x0, x1, y0, y1 = min(xs) - m, max(xs) + m, min(ys) - m, max(ys) + m
        W = int(math.ceil((x1 - x0) * PPM2 / 8) * 8); H = int(math.ceil((y1 - y0) * PPM2 / 8) * 8)
        cxx, cyy = (x0 + x1) / 2, (y0 + y1) / 2
        W += 8; H += 8
        # alinear el ancla con el origen de la oficina (mod 8) para que la posición final sea múltiplo de 8 px
        _OM = json.load(open("/home/claude/kit/office/out/office_meta.json"))["proyeccion"]["origen"]
        _ax = W / 2 + (0 - cxx) * PPM2; _ay = H / 2 - (0 - cyy) * PPM2
        _sx = (_OM[0] - _ax) % 8; _sy = (_OM[1] - _ay) % 8
        cxx -= _sx / PPM2; cyy += _sy / PPM2
        cam.location = cxx * RIGHT + cyy * UP - FWD * 30
        sc.render.resolution_x, sc.render.resolution_y = W, H; cam_data.ortho_scale = max(W, H) / PPM2
        others = [o for o in sc.objects if o.type == "MESH" and o not in objs and o is not catcher]
        for o in others: o.hide_render = True
        # pasada objeto
        catcher.hide_render = True
        for o in objs: o.visible_camera = True
        A = render_to(f"{OUTDIR}/_obj.png")
        # pasada sombra
        catcher.hide_render = False
        for o in objs: o.visible_camera = False
        S = render_to(f"{OUTDIR}/_sh.png")
        catcher.hide_render = True
        lum = S[..., :3].mean(axis=2); mask = S[..., 3] > 0.5
        L0 = np.percentile(lum[mask], 97) if mask.any() else 1
        sh = np.clip((L0 - lum) / max(L0, 1e-6), 0, 1) * mask
        sh = np.clip(sh * 1.15, 0, 0.62)
        # componer: sombra oscura bajo el objeto
        out = np.zeros_like(A)
        out[..., :3] = np.array([0.07, 0.08, 0.11]); out[..., 3] = sh
        a = A[..., 3:4]
        out[..., :3] = A[..., :3] * a + out[..., :3] * (1 - a) * (out[..., 3:4] > 0)
        out[..., 3] = a[..., 0] + sh * (1 - a[..., 0])
        rgb = np.where(out[..., 3:4] > 0, out[..., :3] / np.maximum(out[..., 3:4], 1e-6) * np.where(a > 0, a, 0) + np.where(a > 0, 0, out[..., :3]), 0)
        img = Image.fromarray((np.dstack([np.clip(np.where(a > 0, A[..., :3], out[..., :3]), 0, 1), out[..., 3]]) * 255).astype(np.uint8), "RGBA")
        bb = img.getchannel("A").point(lambda v: 255 if v > 3 else 0).getbbox()
        bx0, by0 = (bb[0] // 8) * 8, (bb[1] // 8) * 8
        bx1, by1 = min(W, ((bb[2] + 7) // 8) * 8), min(H, ((bb[3] + 7) // 8) * 8)
        img = img.crop((bx0, by0, bx1, by1))
        fn_out = f"{OUTDIR}/decor/{oid}_{tag}.png"; img.save(fn_out, optimize=True)
        # ancla: pixel del punto (0,0,0) dentro del sprite recortado
        p0 = Vector((0, 0, 0))
        ax = W / 2 + (p0.dot(RIGHT) - cxx) * PPM2 - bx0
        ay = H / 2 - (p0.dot(UP) - cyy) * PPM2 - by0
        huella = [fw, fd] if (tipo == "pared" or tag == "a") else [fd, fw]
        entry["orientaciones"][tag] = {"sprite": f"decor/{oid}_{tag}.png", "ancla": [round(ax, 2), round(ay, 2)],
                                       "huella_m": huella, "huella_celdas": [int(round(huella[0] / 0.5)) or 1, int(round(huella[1] / 0.5)) or 1],
                                       "tam": [img.width, img.height]}
        bpy.data.objects.remove(catcher, do_unlink=True)
        for o in others: o.hide_render = False
        print("OBJ", oid, tag, img.size)
    for o in reversed(kids(root)): bpy.data.objects.remove(o, do_unlink=True)
    meta["objetos"].append(entry)
for f in ("_obj.png", "_sh.png"):
    try: os.remove(f"{OUTDIR}/{f}")
    except OSError: pass
json.dump(meta, open(f"{OUTDIR}/decor_catalogo{'_' + '_'.join(_ONLY) if _ONLY else ''}.json", "w"), ensure_ascii=False, indent=1)
print("DECOR OK")
