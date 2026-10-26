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

CATALOGO = [
  ("planta", "Planta", planta, 150), ("lampara", "Lámpara de pie", lampara, 200), ("sillon", "Sillón", sillon, 600),
  ("cafetera", "Mesita con cafetera", cafetera, 350), ("librero", "Librero", librero, 450), ("tapete", "Tapete", tapete, 250),
  ("snacks", "Máquina de snacks", snacks, 700), ("consola", "Consola de videojuegos", consola, 900), ("acuario", "Acuario", acuario, 800),
  ("trofeo", "Trofeo Scale-up", trofeo, 0), ("cuadro", "Cuadro", cuadro, 300), ("neon", "Letrero de neón (nombre de tu empresa)", neon, 500),
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
