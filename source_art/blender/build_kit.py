"""
Server Flow 2D — Kit piloto (Blender, headless)
Genera: cuarto base (garage), escritorio + PC, silla, rack (LED verde / rojo), caja.
Cámara ortográfica isométrica 2:1 (elevación 30°, giro 45°) con densidad fija:
1 tile de 1 m = 128 x 64 px (@1x). También exporta @2x.
Uso:  python3 build_kit.py <carpeta_salida> <imagen_menu.png>
"""
import bpy, bmesh, math, sys, os, json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

OUT = sys.argv[1]; MENU_IMG = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
PPM = 128 / math.sqrt(2)          # píxeles por metro @1x  (tile 1x1 m -> 128 px de ancho)

# ---------------- escena base ----------------
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.film_transparent = True
sc.view_settings.view_transform = "Standard"     # colores planos, sin "Filmic/AgX" lavado
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
try:
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = "ABSOLUTE"
    sc.render.line_thickness = 1.0
    ls = sc.view_layers[0].freestyle_settings.linesets[0] if sc.view_layers[0].freestyle_settings.linesets else sc.view_layers[0].freestyle_settings.linesets.new("L")
    ls.linestyle.color = (0.08, 0.09, 0.12)
    ls.linestyle.alpha = 0.55
except Exception as e:
    print("freestyle off:", e)

world = bpy.data.worlds.new("W"); sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.55, 0.58, 0.66, 1); bg.inputs[1].default_value = 0.9

def sun(name, rot, energy, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, "SUN"); l.energy = energy; l.color = color; l.angle = math.radians(8)
    o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.rotation_euler = [math.radians(a) for a in rot]
    return o
sun("Key", (50, 0, 20), 3.2, (1.0, 0.97, 0.92))     # luz principal desde arriba-izquierda
sun("Fill", (65, 0, 200), 0.6, (0.75, 0.82, 1.0))   # relleno frío

# ---------------- materiales ----------------
def hexrgb(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c] + [1]
MATS = {}
def mat(name, hexcol, rough=0.85, emit=0.0, metal=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexrgb(hexcol)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = hexrgb(hexcol); b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m; return m

def screen_mat(path):
    m = bpy.data.materials.new("Pantalla_Menu"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(path)
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.6; b.inputs["Roughness"].default_value = 0.3
    return m

# ---------------- helpers de geometría ----------------
def cube(name, loc, size, m, bevel=0.012, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    if bevel:
        bv = o.modifiers.new("bevel", "BEVEL"); bv.width = bevel; bv.segments = 2
    if parent: o.parent = parent
    return o

def group(name):
    e = bpy.data.objects.new(name, None); sc.collection.objects.link(e); return e

def kids(root):
    return [root] + [c for c in root.children_recursive]

# ---------------- PALETA ----------------
P = dict(concreto="#9aa0a6", pared_izq="#8fa77a", pared_der="#a3bb8c", zoclo="#6d7480",
         madera="#b5773f", madera_osc="#8a5a2e", carcasa="#2a3242", teclado="#4b5568",
         rack="#2b3445", bahia="#151b26", led_ok="#3ddc84", led_bad="#ff4d5e",
         carton="#c79a5b", cinta="#d9c08a", silla="#2a2f3a", taza="#d24a3a",
         puerta="#e8e8e8", manija="#c9a227", pizarron="#f4f4f4", marco="#7e8796", tinta="#222222")
M = {k: mat(k, v) for k, v in P.items()}
M["led_ok"] = mat("led_ok_e", P["led_ok"], 0.4, 6.0)
M["led_bad"] = mat("led_bad_e", P["led_bad"], 0.4, 6.0)
M["carcasa"] = mat("carcasa_m", P["carcasa"], 0.45)
M_SCREEN = screen_mat(MENU_IMG)

# ================= PIEZAS =================
N = 6  # cuarto de 6 x 6 tiles para el piloto

def build_room():
    r = group("Cuarto_Garage")
    cube("Piso", (N/2, N/2, -0.05), (N, N, 0.1), M["concreto"], 0, r)
    # paredes del fondo: plano x=0 (izq) y plano y=N (der)
    cube("Pared_Izq", (-0.06, N/2, 1.6), (0.12, N, 3.2), M["pared_izq"], 0, r)
    cube("Pared_Der", (N/2, N + 0.06, 1.6), (N, 0.12, 3.2), M["pared_der"], 0, r)
    cube("Zoclo_Izq", (0.01, N/2, 0.06), (0.04, N, 0.12), M["zoclo"], 0, r)
    cube("Zoclo_Der", (N/2, N - 0.01, 0.06), (N, 0.04, 0.12), M["zoclo"], 0, r)
    # puerta (pared izq)
    cube("Puerta", (0.02, 4.9, 1.05), (0.05, 1.0, 2.1), M["puerta"], 0.01, r)
    cube("Manija", (0.07, 4.5, 1.0), (0.05, 0.08, 0.05), M["manija"], 0.005, r)
    # pizarrón con el boceto del equipo (pared der)
    cube("Pizarron_Marco", (3.6, N - 0.02, 1.9), (2.2, 0.04, 1.3), M["marco"], 0.01, r)
    cube("Pizarron", (3.6, N - 0.05, 1.9), (2.08, 0.03, 1.18), M["pizarron"], 0, r)
    for (x, z, w, h) in [(2.85, 1.75, .45, .6), (3.5, 1.75, .18, .3), (4.2, 1.75, .45, .38)]:
        for (dx, dz, sw, sh) in [(0, h/2, w, .02), (0, -h/2, w, .02), (-w/2, 0, .02, h), (w/2, 0, .02, h)]:
            cube("Trazo", (x + dx, N - 0.07, z + dz), (sw, 0.01, sh), M["tinta"], 0, r)
    cube("Trazo_Linea", (3.6, N - 0.07, 2.32), (1.9, 0.01, .02), M["tinta"], 0, r)
    # manchas de aceite (detalle de garage)
    for (x, y, s) in [(3.3, 2.6, .45), (4.4, 3.9, .28)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=s, depth=0.004, location=(x, y, 0.003))
        o = bpy.context.active_object; o.scale = (1, .7, 1); o.parent = r
        o.data.materials.append(mat("mancha", "#7f858c"))
    return r

def build_desk(pos):
    r = group("Escritorio_PC"); r.location = pos
    cube("Cubierta", (0.6, 1.1, 0.74), (1.2, 2.2, 0.06), M["madera"], 0.01, r)
    for (x, y) in [(0.08, 0.08), (1.12, 0.08), (0.08, 2.12), (1.12, 2.12)]:
        cube("Pata", (x, y, 0.355), (0.08, 0.08, 0.71), M["madera_osc"], 0.005, r)
    cube("Cajonera", (0.6, 1.85, 0.4), (1.0, 0.5, 0.62), M["madera_osc"], 0.01, r)
    # monitor (pantalla mira hacia +x)
    cube("Base_Monitor", (0.32, 0.95, 0.785), (0.28, 0.4, 0.03), M["carcasa"], 0.005, r)
    cube("Cuello", (0.3, 0.95, 0.9), (0.06, 0.08, 0.22), M["carcasa"], 0.005, r)
    cube("Carcasa", (0.28, 0.95, 1.22), (0.06, 0.92, 0.56), M["carcasa"], 0.01, r)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.315, 0.95, 1.22))
    s = bpy.context.active_object; s.name = "Pantalla"; s.parent = r
    s.rotation_euler = (math.radians(90), 0, math.radians(90)); s.scale = (0.84, 0.48, 1)
    s.data.materials.append(M_SCREEN)
    cube("Teclado", (0.72, 0.95, 0.785), (0.22, 0.6, 0.025), M["teclado"], 0.004, r)
    cube("Mouse", (0.72, 1.4, 0.785), (0.1, 0.06, 0.025), M["teclado"], 0.004, r)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.11, location=(0.55, 0.3, 0.825))
    t = bpy.context.active_object; t.name = "Taza"; t.parent = r; t.data.materials.append(M["taza"])
    return r

def build_chair(pos):
    r = group("Silla"); r.location = pos
    cube("Asiento", (0, 0, 0.47), (0.5, 0.5, 0.08), M["silla"], 0.02, r)
    cube("Respaldo", (0.24, 0, 0.82), (0.07, 0.48, 0.6), M["silla"], 0.03, r)
    cube("Poste", (0, 0, 0.24), (0.06, 0.06, 0.4), M["teclado"], 0, r)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        cube("Pata", (0.16 * math.cos(ang), 0.16 * math.sin(ang), 0.04), (0.3 if a % 2 == 0 else 0.06, 0.06 if a % 2 == 0 else 0.3, 0.04), M["teclado"], 0, r)
    return r

def build_rack(pos, led_mat, name):
    r = group(name); r.location = pos
    cube("Gabinete", (0.35, 0.35, 1.0), (0.7, 0.7, 2.0), M["rack"], 0.015, r)
    for i in range(8):
        z = 0.2 + i * 0.22
        cube("Bahia", (0.35, -0.005, z), (0.58, 0.02, 0.14), M["bahia"], 0.003, r)
        cube("LED", (0.58, -0.02, z), (0.04, 0.02, 0.04), led_mat, 0, r)
        cube("LED2", (0.51, -0.02, z), (0.03, 0.02, 0.03), led_mat if i % 2 else M["teclado"], 0, r)
    # cara lateral +x también con rejilla
    for i in range(4):
        cube("Rejilla", (0.705, 0.35, 0.4 + i * 0.4), (0.01, 0.5, 0.02), M["bahia"], 0, r)
    return r

def build_box(pos, size=(0.6, 0.5, 0.45), name="Caja"):
    r = group(name); r.location = pos
    w, d, h = size
    cube("Carton", (w/2, d/2, h/2), size, M["carton"], 0.01, r)
    cube("Cinta", (w/2, d/2, h + 0.001), (0.08, d + 0.002, 0.004), M["cinta"], 0, r)
    cube("Cinta_frente", (w/2, -0.001, h - 0.08), (0.08, 0.004, 0.16), M["cinta"], 0, r)
    return r

room = build_room()
desk = build_desk((0.15, 1.2, 0))
chair = build_chair((1.62, 2.15, 0))
rack_ok = build_rack((0.2, 4.8, 0), M["led_ok"], "Rack_OK")  # junto a la puerta? se mueve abajo
rack_ok.location = (0.9, 5.15, 0)
rack_bad = build_rack((0, 0, 0), M["led_bad"], "Rack_Saturado")
box1 = build_box((4.2, 1.1, 0), (0.7, 0.6, 0.5), "Caja_Grande")
box2 = build_box((4.3, 1.2, 0.5), (0.5, 0.42, 0.34), "Caja_Chica")
box3 = build_box((5.0, 2.4, 0), (0.55, 0.5, 0.4), "Caja_Suelta")

# ---------------- cámara ----------------
cam_data = bpy.data.cameras.new("IsoCam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("IsoCam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
cam.rotation_euler = (math.radians(60), 0, math.radians(45))   # 2:1 dimétrica
bpy.context.view_layer.update()
R = cam.matrix_world.to_3x3()
RIGHT, UP, FWD = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))

def world_pts(objs):
    pts = []
    for o in objs:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    return pts

def frame(objs, scale=1, pad=6):
    pts = world_pts(objs)
    xs = [p.dot(RIGHT) for p in pts]; ys = [p.dot(UP) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    wpx = (max(xs) - min(xs)) * PPM * scale + 2 * pad; hpx = (max(ys) - min(ys)) * PPM * scale + 2 * pad
    wpx, hpx = int(math.ceil(wpx / 2) * 2), int(math.ceil(hpx / 2) * 2)
    center = cx * RIGHT + cy * UP
    cam.location = center - FWD * 30
    sc.render.resolution_x, sc.render.resolution_y = wpx, hpx
    sc.render.resolution_percentage = 100
    cam_data.ortho_scale = max(wpx, hpx) / (PPM * scale)
    return wpx, hpx

def isolate(root):
    keep = set(kids(root))
    for o in sc.objects:
        if o.type in ("MESH", "EMPTY"):
            o.hide_render = o not in keep

def show_all(exclude=()):
    ex = set()
    for e in exclude: ex |= set(kids(e))
    for o in sc.objects:
        if o.type in ("MESH", "EMPTY"): o.hide_render = o in ex

def render(path):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

meta = {"tile_px": [128, 64], "ppm_1x": PPM, "props": {}}
pieces = {"cuarto_garage": room, "escritorio_pc": desk, "silla": chair,
          "rack_ok": rack_ok, "rack_saturado": rack_bad, "caja_grande": box1, "caja_suelta": box3}
# las cajas apiladas se renderizan juntas
pieces_extra = {"cajas_apiladas": [box1, box2]}

for scale, tag in [(1, "1x"), (2, "2x")]:
    for name, root in pieces.items():
        if name == "caja_grande": continue
        isolate(root); w, h = frame(kids(root), scale)
        render(f"{OUT}/props_{tag}/{name}.png")
        meta["props"].setdefault(name, {})[tag] = [w, h]
    for name, roots in pieces_extra.items():
        keep = set(); [keep.update(kids(r)) for r in roots]
        for o in sc.objects:
            if o.type in ("MESH", "EMPTY"): o.hide_render = o not in keep
        w, h = frame(list(keep), scale); render(f"{OUT}/props_{tag}/{name}.png")
        meta["props"].setdefault(name, {})[tag] = [w, h]

# ---------------- escena compuesta (vista del juego) ----------------
show_all(exclude=[rack_bad])
w, h = frame(kids(room) + kids(desk) + kids(rack_ok), 1.6, pad=30)
render(f"{OUT}/escena_garage.png")
# posición de la silla en la imagen (para colocar a Alex en 2D)
seat = chair.matrix_world @ Vector((0.0, 0, 0.5))
co = world_to_camera_view(sc, cam, seat)
meta["escena"] = {"size": [w, h], "silla_px": [co.x * w, (1 - co.y) * h], "ppm": PPM * 1.6}
# versión saturada (rack rojo en lugar del verde)
rack_bad.location = rack_ok.location
show_all(exclude=[rack_ok])
render(f"{OUT}/escena_garage_saturado.png")
rack_bad.location = (0, 0, 0)  # se queda fuera de cuadro en el .blend
rack_bad.location = (5.0, 4.4, 0)
show_all()
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/kit_piloto_garage.blend")
json.dump(meta, open(f"{OUT}/meta.json", "w"), indent=1)
print("LISTO", json.dumps(meta))
