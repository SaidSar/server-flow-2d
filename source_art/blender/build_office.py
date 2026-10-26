"""
Oficina (etapa 2 · Scale-up) — Server Flow 2D.
Cuarto 9x9 m. Conserva escritorio, silla, avatar y puerta en la MISMA posición del mundo que el garage,
así sus sprites se reutilizan con un desplazamiento (dx, dy). Los racks se mueven a la pared derecha.
Renderiza a 2x: piso (3 variantes), pared_izq (10), pared_der (10), capa 'ventanas' (luz),
y escribe office_meta.json con: lienzo, proyección mundo→píxel (para colocación libre),
desplazamientos de los sprites reutilizados y zonas ocupadas.
Uso: python3 build_office.py <salida> <menu.png> [preview]
"""
import sys, math, json, os
import bpy
from mathutils import Vector
OUTDIR = sys.argv[1]; MENU = sys.argv[2]; PREVIEW = len(sys.argv) > 3
SRC = open("/home/claude/kit/build_kit.py").read()
sys.argv = [sys.argv[0], OUTDIR, MENU]
exec(SRC[:SRC.index("room = build_room()")])
sc.eevee.taa_render_samples = 16   # escena, luces, materiales M, build_desk/chair/rack

N = 9
P2 = dict(lam="#c9a77c", lam_seam="#a8875e", marco_ven="#eef1f4", vidrio="#9fd3f2", repisa="#d9d4c7", pizarra="#f4f4f4")
M["piso_of"] = mat("piso_of", P2["lam"], 0.6)
M["junta"] = mat("junta", P2["lam_seam"], 0.7)
M["marco_ven"] = mat("marco_ven", P2["marco_ven"], 0.5)
M["vidrio"] = mat("vidrio", P2["vidrio"], 0.15, 1.4)
M["cielo2"] = mat("cielo2", "#cfe9f8", 0.2, 1.8)

def build_office():
    r = group("Oficina")
    cube("Piso", (N/2, N/2, -0.05), (N, N, 0.1), M["piso_of"], 0, r)
    for i in range(1, int(N / 0.3)):                       # juntas del laminado (tablas de 30 cm a lo largo de X)
        cube("Junta", (N/2, i * 0.3, 0.001), (N, 0.012, 0.002), M["junta"], 0, r)
    for k in range(int(N / 1.2)):                          # juntas cortas escalonadas
        for i in range(int(N / 0.3)):
            x = (k * 1.2 + (0.6 if i % 2 else 0)) % N
            if 0.05 < x < N - 0.05:
                cube("JuntaT", (x, i * 0.3 + 0.15, 0.001), (0.012, 0.3, 0.002), M["junta"], 0, r)
    cube("Pared_Izq", (-0.06, N/2, 1.6), (0.12, N, 3.2), M["pared_izq"], 0, r)
    cube("Pared_Der", (N/2, N + 0.06, 1.6), (N, 0.12, 3.2), M["pared_der"], 0, r)
    cube("Zoclo_Izq", (0.01, N/2, 0.06), (0.04, N, 0.12), M["zoclo"], 0, r)
    cube("Zoclo_Der", (N/2, N - 0.01, 0.06), (N, 0.04, 0.12), M["zoclo"], 0, r)
    # puerta: misma posición que el garage
    cube("Puerta", (0.02, 4.9, 1.05), (0.05, 1.0, 2.1), M["puerta"], 0.01, r)
    cube("Manija", (0.07, 4.5, 1.0), (0.05, 0.08, 0.05), M["manija"], 0.005, r)
    # ventanas en la pared derecha (plano y = N)
    for x0 in (4.1, 6.6):
        w = 1.7
        cube("Ven_Vidrio", (x0 + w/2, N - 0.015, 1.75), (w - 0.1, 0.02, 1.3), M["vidrio"], 0, r)
        cube("Ven_Cielo", (x0 + w/2, N - 0.012, 2.05), (w - 0.1, 0.018, 0.55), M["cielo2"], 0, r)
        for (dx, dz, sw, sh) in [(0, 0.7, w, .06), (0, -0.7, w, .06), (-w/2, 0, .06, 1.46), (w/2, 0, .06, 1.46), (0, 0, .04, 1.4), (0, 0.05, w, .04)]:
            cube("Ven_Marco", (x0 + w/2 + dx, N - 0.04, 1.75 + dz), (sw, 0.06, sh), M["marco_ven"], 0.005, r)
        cube("Ven_Repisa", (x0 + w/2, N - 0.08, 1.0), (w + 0.12, 0.16, 0.05), M["marco_ven"], 0.01, r)
    # pizarrón en la pared izquierda (plano x = 0) con el boceto del equipo
    cube("Pizarron_Marco", (0.02, 7.4, 1.9), (0.04, 2.2, 1.3), M["marco"], 0.01, r)
    cube("Pizarron", (0.05, 7.4, 1.9), (0.03, 2.08, 1.18), M["pizarron"], 0, r)
    for (y, z, w, h) in [(6.65, 1.75, .45, .6), (7.3, 1.75, .18, .3), (8.0, 1.75, .45, .38)]:
        for (dy, dz, sw, sh) in [(0, h/2, w, .02), (0, -h/2, w, .02), (-w/2, 0, .02, h), (w/2, 0, .02, h)]:
            cube("Trazo", (0.07, y + dy, z + dz), (0.01, sw, sh), M["tinta"], 0, r)
    cube("Trazo_Linea", (0.07, 7.4, 2.32), (0.01, 1.9, .02), M["tinta"], 0, r)
    # logo/letrero de la empresa (marco vacío: el texto lo pone Godot con el nombre del jugador)
    return r

office = build_office()
desk = build_desk((0.15, 1.2, 0))
chair = build_chair((1.45, 2.15, 0))
rack1 = build_rack((0.9, 8.15, 0), M["led_ok"], "Rack_1")
rack2 = build_rack((1.65, 8.15, 0), M["led_ok"], "Rack_2")

# avatar (solo para que proyecte su sombra en el piso)
with bpy.data.libraries.load("/home/claude/kit/out_alex/garage_con_alex.blend") as (src, dst):
    dst.objects = list(src.objects)
alex_root = next(o for o in dst.objects if o and o.name.startswith("Alex_teclea_a"))
def desc(root, pool):
    out = [root]
    for o in pool:
        if o and o.parent and o.parent in out and o not in out: out.append(o)
    return out
pool = [o for o in dst.objects if o]
alex_objs = [alex_root]
changed = True
while changed:
    changed = False
    for o in pool:
        if o.parent in alex_objs and o not in alex_objs:
            alex_objs.append(o); changed = True
for o in alex_objs: sc.collection.objects.link(o)

# ---------------- cámara ----------------
cam_data = bpy.data.cameras.new("IsoCam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("IsoCam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
cam.rotation_euler = (math.radians(60), 0, math.radians(45))
bpy.context.view_layer.update()
R = cam.matrix_world.to_3x3()
RIGHT, UP, FWD = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
SCALE = 2; PPM2 = PPM * SCALE
def K(r): return [r] + list(r.children_recursive)
pts = [o.matrix_world @ Vector(c) for o in K(office) + K(desk) + K(rack1) + K(rack2) if o.type == "MESH" for c in o.bound_box]
xs = [p.dot(RIGHT) for p in pts]; ys = [p.dot(UP) for p in pts]
cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
pad = 12
W = int(math.ceil(((max(xs) - min(xs)) * PPM2 + 2 * pad) / 8) * 8)
H = int(math.ceil(((max(ys) - min(ys)) * PPM2 + 2 * pad) / 8) * 8)
W += 8; H += 8
# alinear: el desplazamiento de los sprites del garage debe ser múltiplo de 8 px
_G = json.load(open("/home/claude/kit/office/garage_proj.json"))
def _d0():
    p = Vector((0, 0, 0))
    ox = W / 2 + (p.dot(RIGHT) - cx) * PPM2; oy = H / 2 - (p.dot(UP) - cy) * PPM2
    gx = _G["W"] / 2 + (p.dot(RIGHT) - _G["cx"]) * _G["ppm"]; gy = _G["H"] / 2 - (p.dot(UP) - _G["cy"]) * _G["ppm"]
    return ox - gx, oy - gy
dx0, dy0 = _d0()
sx = math.ceil(round(dx0, 4) / 8) * 8 - dx0; sy = math.ceil(round(dy0, 4) / 8) * 8 - dy0
cx -= sx / PPM2; cy += sy / PPM2
cam.location = cx * RIGHT + cy * UP - FWD * 30
sc.render.resolution_x, sc.render.resolution_y = W, H
cam_data.ortho_scale = max(W, H) / PPM2
if PREVIEW: sc.render.resolution_percentage = 50

def proj(p, c=(cx, cy), w=W, h=H, ppm=PPM2):
    p = Vector(p)
    return (w / 2 + (p.dot(RIGHT) - c[0]) * ppm, h / 2 - (p.dot(UP) - c[1]) * ppm)

G = json.load(open("/home/claude/kit/office/garage_proj.json"))
def proj_g(p):
    p = Vector(p)
    return (G["W"] / 2 + (p.dot(RIGHT) - G["cx"]) * G["ppm"], G["H"] / 2 - (p.dot(UP) - G["cy"]) * G["ppm"])
def delta(world_move=(0, 0, 0), ref=(0, 0, 0)):
    a = proj_g(ref); b = proj(Vector(ref) + Vector(world_move))
    return [round(b[0] - a[0], 3), round(b[1] - a[1], 3)]

ALL = [o for o in sc.objects if o.type == "MESH"]
LAYERS = {
    "piso": [o for o in office.children if o.name.startswith(("Piso", "Junta"))],
    "pared_izq": [o for o in office.children if o.name.startswith(("Pared_Izq", "Zoclo_Izq", "Pizarron", "Trazo"))],
    "pared_der": [o for o in office.children if o.name.startswith(("Pared_Der", "Zoclo_Der", "Ven_"))],
}
def only(objs, path):
    keep = set(objs)
    for o in ALL: o.visible_camera = o in keep
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
def setcol(m, hx):
    bpy.data.materials[m].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexrgb(hx)

PAL_PISO = [("laminado_claro", "Laminado claro", "#c9a77c", "#a8875e"), ("laminado_oscuro", "Laminado nogal", "#7a5638", "#5e3f27"),
            ("alfombra_gris", "Alfombra gris", "#8c929b", "#858b94")]
PARED = json.load(open("/home/claude/kit/out_custom/paleta.json"))["paleta"]["pared"]

if PREVIEW:
    setcol("pared_izq", "#e6e1d4"); setcol("pared_der", "#e6e1d4")
    for o in ALL: o.visible_camera = True
    sc.render.filepath = f"{OUTDIR}/preview_oficina.png"; bpy.ops.render.render(write_still=True)
    print("PREVIEW OK", W, H); sys.exit(0)

for d in ("piso", "pared_izq", "pared_der"): os.makedirs(f"{OUTDIR}/2x/{d}", exist_ok=True)
for vid, name, hx, seam in PAL_PISO:
    setcol("piso_of", hx); setcol("junta", seam); only(LAYERS["piso"], f"{OUTDIR}/2x/piso/{vid}.png")
for v in PARED:
    setcol("pared_izq", v["color"]); only(LAYERS["pared_izq"], f"{OUTDIR}/2x/pared_izq/{v['id']}.png")
    setcol("pared_der", v["color"]); only(LAYERS["pared_der"], f"{OUTDIR}/2x/pared_der/{v['id']}.png")

# ---------------- metadatos ----------------
ex = [RIGHT.x * PPM2, -UP.x * PPM2]; ey = [RIGHT.y * PPM2, -UP.y * PPM2]; ez = [RIGHT.z * PPM2, -UP.z * PPM2]
origin = proj((0, 0, 0))
meta = {
  "room": "oficina", "canvas": [W, H], "escala_nodo": 0.5,
  "proyeccion": {"nota": "pixel(lienzo 2x) = origen + x*ex + y*ey + z*ez  (x, y, z en metros del mundo)",
                 "origen": [round(origin[0], 3), round(origin[1], 3)], "ex": ex, "ey": ey, "ez": ez},
  "cuadricula": {"celda_m": 0.5, "x": [0, N], "y": [0, N],
                 "ocupado_m": [{"id": "escritorio_y_silla", "x": [0.0, 2.0], "y": [1.0, 3.6]},
                               {"id": "puerta", "x": [0.0, 1.2], "y": [4.3, 5.5]},
                               {"id": "racks", "x": [0.8, 2.5], "y": [8.0, 9.0]}],
                 "nota": "zonas ocupadas en metros (no se puede colocar decoración ahí)."},
  "reutilizados_del_garage": {
      "nota": "Usar el MISMO sprite del garage y sumar (dx, dy) a su offset del garage (lienzo 2x).",
      "mesa/*": delta(), "puerta/*": delta(), "alex/*": delta(), "alexa/*": delta(),
      "rack_1 (fijos/rack_ok|rack_saturado)": delta((0, 3, 0), (0.9, 5.15, 0)),
      "rack_2 (fijos/rack_ok|rack_saturado)": delta((0.75, 3, 0), (0.9, 5.15, 0)),
  },
  "orden_capas": ["piso", "pared_izq", "pared_der", "puerta", "racks", "decoracion (y-sort)", "mesa", "avatar"],
  "paleta_piso": [dict(id=v[0], nombre=v[1], color=v[2]) for v in PAL_PISO],
}
json.dump(meta, open(f"{OUTDIR}/office_meta.json", "w"), ensure_ascii=False, indent=1)
for o in ALL: o.visible_camera = True
bpy.ops.wm.save_as_mainfile(filepath=f"{OUTDIR}/oficina.blend")
print("OFICINA OK", W, H)
