"""
Alex 3D (low-poly estilizado) para Server Flow 2D.
Abre el kit del garage, acerca la silla al escritorio, modela a Alex en varias poses y renderiza:
  - escena con Alex (normal / saturado)
  - sprites "Alex en silla" por pose (1x/2x)   -> se usan directo en Godot (silla incluida, sin capas)
  - Alex de pie (1x/2x)
Uso: python3 alex3d.py <carpeta_kit_out> <carpeta_salida>
"""
import bpy, math, sys, os, json
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

KIT, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{KIT}/kit_piloto_garage.blend")
sc = bpy.context.scene
cam = bpy.data.objects["IsoCam"]; cam_data = cam.data
PPM = 128 / math.sqrt(2)
R = cam.matrix_world.to_3x3()
RIGHT, UP, FWD = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))

silla = bpy.data.objects["Silla"]; silla.location = (1.45, 2.15, 0)
rack_ok = bpy.data.objects["Rack_OK"]; rack_bad = bpy.data.objects["Rack_Saturado"]

def hexrgb(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c] + [1]
_M = {}
def mat(name, hexcol, rough=0.8, emit=0):
    if name in _M: return _M[name]
    m = bpy.data.materials.new("Alex_" + name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexrgb(hexcol); b.inputs["Roughness"].default_value = rough
    if emit: b.inputs["Emission Color"].default_value = hexrgb(hexcol); b.inputs["Emission Strength"].default_value = emit
    _M[name] = m; return m

C = dict(piel=mat("piel", "#e0ad86", .7), pelo=mat("pelo", "#3b2416", .9), sudadera=mat("sudadera", "#2f6bdc"),
         sudadera_osc=mat("sudadera_osc", "#2557b8"), pantalon=mat("pantalon", "#232c3d"), tenis=mat("tenis", "#f1f3f6", .6),
         franja=mat("franja", "#ff4d5e"), audif=mat("audif", "#111722", .4), led=mat("led", "#5aa9ff", .3, 4),
         cordon=mat("cordon", "#e9edf2"), ojo=mat("ojo", "#1a1a1a", .3), credencial=mat("credencial", "#f4f4f4", .5))

# ---------------- primitivas ----------------
ROOT = None
def _finish(o, m, smooth=True):
    o.data.materials.append(m); o.parent = ROOT
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    return o

def ball(p, r, m, scale=(1, 1, 1), seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=p, segments=seg, ring_count=seg // 2)
    o = bpy.context.active_object; o.scale = scale; return _finish(o, m)

def limb(a, b, r, m, r2=None, caps=True):
    a, b = Vector(a), Vector(b); d = b - a; L = d.length
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=r, radius2=r2 if r2 else r, depth=L, location=(a + b) / 2)
    o = bpy.context.active_object
    o.rotation_mode = "QUATERNION"; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    _finish(o, m)
    if caps:
        ball(a, r, m, seg=12); ball(b, r2 if r2 else r, m, seg=12)
    return o

def rbox(p, size, m, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p, rotation=rot)
    o = bpy.context.active_object; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    bv = o.modifiers.new("b", "BEVEL"); bv.width = bevel; bv.segments = 3
    return _finish(o, m)

# ---------------- Alex ----------------
def build_alex(pose, origin):
    """pose: 'teclea_a' | 'teclea_b' | 'estres' | 'pie'. origin: punto entre las caderas (sentado) o entre los pies (de pie).
    Alex mira hacia -X (hacia el monitor)."""
    global ROOT
    ROOT = bpy.data.objects.new("Alex_" + pose, None); sc.collection.objects.link(ROOT)
    O = Vector(origin)
    def P(x, y, z): return O + Vector((x, y, z))
    seated = pose != "pie"
    lean = 0.08 if pose.startswith("teclea") else (0.02 if pose == "estres" else 0)

    # --- piernas ---
    for s in (-1, 1):
        y = 0.095 * s
        if seated:
            hip, knee, ankle = P(0.02, y, 0.0), P(-0.40, y, 0.02), P(-0.44, y * 1.05, -0.43)
        else:
            hip, knee, ankle = P(0, y, 0.86), P(0, y, 0.48), P(0, y, 0.09)
        limb(hip, knee, 0.075, C["pantalon"], 0.065)
        limb(knee, ankle, 0.062, C["pantalon"], 0.05)
        f = ankle + Vector((-0.07, 0, -0.04))
        rbox(f, (0.24, 0.1, 0.08), C["tenis"], 0.03)
        rbox(f + Vector((0.0, -0.051 * 1, 0.0)) if s < 0 else f + Vector((0, 0.051, 0)), (0.18, 0.004, 0.025), C["franja"], 0.002)

    # --- torso (sudadera) ---
    base_z = 0.0 if seated else 0.86
    hipc = P(0.04, 0, base_z + 0.04)
    chest = P(0.04 - lean * 2.2, 0, base_z + 0.46)
    t = limb(hipc, chest, 0.158, C["sudadera"], 0.152, caps=False)
    ball(hipc, 0.172, C["sudadera"], (1, 1.05, .6), seg=24)
    ball(chest, 0.168, C["sudadera"], (1, 1.15, .75), seg=24)
    # capucha caída en la espalda + cordones + bolsillo canguro
    bpy.ops.mesh.primitive_torus_add(major_radius=0.1, minor_radius=0.045, location=chest + Vector((0.07, 0, 0.1)), rotation=(0, math.radians(70), 0))
    _hood = _finish(bpy.context.active_object, C["sudadera_osc"]); _hood.scale = (1.15, 1.25, 0.7)
    for s in (-1, 1):
        limb(chest + Vector((-0.15, 0.035 * s, 0.06)), chest + Vector((-0.17, 0.04 * s, -0.08)), 0.008, C["cordon"])
    rbox(P(-0.13 - lean, 0, base_z + 0.16), (0.04, 0.2, 0.12), C["sudadera_osc"], 0.02)
    # credencial
    rbox(chest + Vector((-0.17, -0.07, -0.14)), (0.01, 0.05, 0.07), C["credencial"], 0.005)

    # --- cabeza ---
    neck = chest + Vector((-0.01, 0, 0.13))
    limb(chest + Vector((0, 0, 0.06)), neck, 0.05, C["piel"], caps=False)
    tilt = {"estres": (0, math.radians(-12), math.radians(14))}.get(pose, (0, 0, 0))
    hc = neck + Vector((-0.02, 0, 0.15))
    if pose == "estres": hc += Vector((0.0, -0.02, -0.01))
    head = ball(hc, 0.15, C["piel"], (1, .95, 1.05), seg=24)
    head.rotation_euler = tilt
    # pelo: casco + fleco + coronilla
    hair = ball(hc + Vector((0.025, 0, 0.03)), 0.158, C["pelo"], (1.02, 1.0, 1.0), seg=24)
    hair.rotation_euler = tilt
    for dy, dz in [(-0.06, 0.12), (0.0, 0.14), (0.06, 0.12)]:
        ball(hc + Vector((-0.08, dy, dz)), 0.06, C["pelo"], (1, 1, .7), seg=10)
    ball(hc + Vector((0.12, 0, 0.0)), 0.1, C["pelo"], (.8, 1.1, 1.2), seg=12)  # nuca
    # cara (mira a -X): ojos, nariz, orejas
    for s in (-1, 1):
        ball(hc + Vector((-0.142, 0.055 * s, 0.01)), 0.018, C["ojo"], (0.6, 1, 1.3), seg=8)
        ball(hc + Vector((0.0, 0.15 * s, -0.01)), 0.035, C["piel"], (0.7, 0.5, 1), seg=8)
    ball(hc + Vector((-0.155, 0, -0.03)), 0.022, C["piel"], seg=8)
    # audífonos
    arc = [hc + Vector((0.01, 0.168 * math.cos(math.radians(a)), 0.168 * math.sin(math.radians(a)))) for a in range(0, 181, 20)]
    for p0, p1 in zip(arc, arc[1:]):
        limb(p0, p1, 0.018, C["audif"])
    for s in (-1, 1):
        cup = limb(hc + Vector((0.01, 0.15 * s, 0.0)), hc + Vector((0.01, 0.2 * s, 0.0)), 0.06, C["audif"], caps=False)
        ball(hc + Vector((0.01, 0.205 * s, 0.0)), 0.035, C["led"], (1, .4, 1), seg=10)

    # --- brazos ---
    sh = {s: chest + Vector((0.0, 0.2 * s, 0.07)) for s in (-1, 1)}
    if pose.startswith("teclea"):
        kb_x = -0.56; kb_z = 0.255  # teclado relativo a la cadera
        off = {"teclea_a": (0.03, -0.03), "teclea_b": (-0.03, 0.03)}[pose]
        for i, s in enumerate((-1, 1)):
            elbow = P(-0.2, 0.22 * s, 0.24)
            hand = P(kb_x + off[i], 0.12 * s, kb_z + 0.03)
            limb(sh[s], elbow, 0.062, C["sudadera"], 0.058)
            limb(elbow, hand + Vector((0.08, 0, 0)), 0.056, C["sudadera"], 0.05)
            ball(hand, 0.045, C["piel"], (1.3, 1, .7), seg=10)
    elif pose == "estres":   # manos en la cabeza
        for s in (-1, 1):
            elbow = chest + Vector((-0.12, 0.33 * s, 0.2))
            hand = hc + Vector((-0.02, 0.16 * s, 0.1))
            limb(sh[s], elbow, 0.062, C["sudadera"], 0.058)
            limb(elbow, hand, 0.056, C["sudadera"], 0.05)
            ball(hand, 0.048, C["piel"], seg=10)
    else:  # de pie, brazos relajados
        for s in (-1, 1):
            elbow = sh[s] + Vector((0.02, 0.04 * s, -0.27))
            hand = elbow + Vector((-0.04, 0.0, -0.25))
            limb(sh[s], elbow, 0.062, C["sudadera"], 0.058)
            limb(elbow, hand, 0.056, C["sudadera"], 0.05)
            ball(hand, 0.048, C["piel"], seg=10)
    return ROOT

def kids(r): return [r] + list(r.children_recursive)
def remove(r):
    for o in reversed(kids(r)): bpy.data.objects.remove(o, do_unlink=True)

# ---------------- render helpers ----------------
def frame(objs, scale=1, pad=6):
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    xs = [p.dot(RIGHT) for p in pts]; ys = [p.dot(UP) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    w = int(math.ceil(((max(xs) - min(xs)) * PPM * scale + 2 * pad) / 2) * 2)
    h = int(math.ceil(((max(ys) - min(ys)) * PPM * scale + 2 * pad) / 2) * 2)
    cam.location = cx * RIGHT + cy * UP - FWD * 30
    sc.render.resolution_x, sc.render.resolution_y = w, h
    cam_data.ortho_scale = max(w, h) / (PPM * scale)
    return w, h

def visible_only(objs):
    keep = set(objs)
    for o in sc.objects:
        if o.type in ("MESH", "EMPTY"): o.hide_render = o not in keep

def render(path):
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

bpy.context.view_layer.update()
SEAT = silla.matrix_world @ Vector((0.0, 0, 0.56))
meta = {}
room = bpy.data.objects["Cuarto_Garage"]; desk = bpy.data.objects["Escritorio_PC"]
others = [bpy.data.objects[n] for n in ("Caja_Grande", "Caja_Chica", "Caja_Suelta")]

# --- escenas ---
for pose, rack_show, rack_hide, tag in [("teclea_a", rack_ok, rack_bad, "normal"), ("estres", rack_bad, rack_ok, "saturado"), ("teclea_b", rack_ok, rack_bad, "normal_b")]:
    rack_bad.location = (0.9, 5.15, 0) if rack_show is rack_bad else (9, 9, 0)
    a = build_alex(pose, SEAT); bpy.context.view_layer.update()
    scene_objs = kids(room) + kids(desk) + kids(silla) + kids(rack_show) + sum((kids(o) for o in others), []) + kids(a)
    visible_only(scene_objs)
    frame(kids(room) + kids(desk) + kids(rack_ok if rack_show is rack_ok else rack_show), 1.6, pad=30)
    render(f"{OUT}/escena_alex3d_{tag}.png")
    if pose == "teclea_a":
        co = world_to_camera_view(sc, cam, SEAT); meta["seat_px"] = [co.x * sc.render.resolution_x, (1 - co.y) * sc.render.resolution_y]
    remove(a)
rack_bad.location = (5.0, 4.4, 0)

# --- sprites Alex en silla, por pose ---
for pose in ("teclea_a", "teclea_b", "estres"):
    a = build_alex(pose, SEAT); bpy.context.view_layer.update()
    objs = kids(silla) + kids(a); visible_only(objs)
    for scale, tag in [(1, "1x"), (2, "2x")]:
        w, h = frame(objs, scale); render(f"{OUT}/sprites_{tag}/alex_silla_{pose}.png"); meta[f"alex_silla_{pose}_{tag}"] = [w, h]
    if pose != "teclea_a": remove(a)
    else: keep_a = a

# --- Alex de pie (pose de referencia / caminar a futuro) ---
stand = build_alex("pie", (0, 0, 0)); stand.rotation_euler = (0, 0, math.radians(120)); stand.location = (3.2, 3.6, 0); bpy.context.view_layer.update()
visible_only(kids(stand))
for scale, tag in [(1, "1x"), (2, "2x"), (4, "ref")]:
    w, h = frame(kids(stand), scale); render(f"{OUT}/sprites_{tag}/alex_de_pie.png"); meta[f"alex_de_pie_{tag}"] = [w, h]


for o in sc.objects:
    if o.type in ("MESH", "EMPTY"): o.hide_render = False
rack_bad.hide_render = True
for o in rack_bad.children_recursive: o.hide_render = True
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/garage_con_alex.blend")
json.dump(meta, open(f"{OUT}/meta_alex.json", "w"), indent=1)
print("ALEX OK", json.dumps(meta))
