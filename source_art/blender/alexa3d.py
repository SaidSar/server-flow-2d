"""
Alexa (versión femenina del avatar) — mismo modelo base que Alex con:
sudadera rosa, cabello largo con coleta alta y mechones laterales, liga rosa.
Renderiza capas a lienzo completo 2x (con sombras) y la pose de pie de referencia.
Uso: python3 alexa3d.py <kit_out> <salida>
"""
import sys, os, json, math
import bpy
from mathutils import Vector
KIT_OUT, OUT = sys.argv[1], sys.argv[2]
SRC = open("/home/claude/kit/alex3d.py").read()
chunk = SRC[:SRC.index("# ---------------- render helpers")]
# --- parche: parámetro fem y cabello largo ---
chunk = chunk.replace("def build_alex(pose, origin):", "def build_alex(pose, origin, fem=False):")
anchor = '    ball(hc + Vector((0.12, 0, 0.0)), 0.1, C["pelo"], (.8, 1.1, 1.2), seg=12)  # nuca\n'
assert anchor in chunk
fem_block = anchor + '''    if fem:
        # coleta alta (atrás = +X)
        for p, r in [((0.15, 0, 0.10), 0.062), ((0.21, 0, 0.04), 0.068), ((0.24, 0, -0.06), 0.064),
                     ((0.25, 0, -0.16), 0.056), ((0.24, 0, -0.25), 0.044), ((0.22, 0, -0.32), 0.032)]:
            ball(hc + Vector(p), r, C["pelo"], seg=12)
        ball(hc + Vector((0.155, 0, 0.115)), 0.04, C["liga"], (1, 1.3, .8), seg=10)   # liga
        # mechones laterales que enmarcan la cara
        for s in (-1, 1):
            for p, r in [((-0.06, 0.125, 0.02), 0.06), ((-0.07, 0.13, -0.07), 0.05), ((-0.06, 0.12, -0.14), 0.04)]:
                ball(hc + Vector((p[0], p[1] * s, p[2])), r, C["pelo"], (0.8, 0.7, 1.1), seg=10)
        # fleco de lado
        ball(hc + Vector((-0.11, -0.04, 0.10)), 0.075, C["pelo"], (0.7, 1.4, 0.6), seg=12)
        # pestañas
        for s in (-1, 1):
            ball(hc + Vector((-0.145, 0.055 * s, 0.035)), 0.012, C["ojo"], (0.5, 1.6, 0.5), seg=8)
'''
chunk = chunk.replace(anchor, fem_block)
chunk = chunk.replace('cordon=mat("cordon", "#e9edf2"),', 'cordon=mat("cordon", "#e9edf2"), liga=mat("liga", "#ff8fc2", .5),')
sys.argv = [sys.argv[0], KIT_OUT, OUT]
exec(chunk)

# sudadera rosa
def recolor(name, hx):
    _M[name].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexrgb(hx)
recolor("sudadera", "#e8649b"); recolor("sudadera_osc", "#c94d82")

os.makedirs(OUT, exist_ok=True)
bpy.context.view_layer.update()
SEAT = silla.matrix_world @ Vector((0.0, 0, 0.56))

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

O = bpy.data.objects
room = O["Cuarto_Garage"]; desk = O["Escritorio_PC"]; rack_ok = O["Rack_OK"]; rack_bad = O["Rack_Saturado"]
rack_bad.hide_render = True
for o in rack_bad.children_recursive: o.hide_render = True
def K(r): return [r] + list(r.children_recursive)
# paleta por defecto del juego para que las sombras coincidan
for m, hx in [("concreto", "#b3aa9c"), ("pared_izq", "#e6e1d4"), ("pared_der", "#e6e1d4"), ("puerta", "#b5773f")]:
    bpy.data.materials[m].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexrgb(hx)

frame(K(room) + K(desk) + K(rack_ok), 2, pad=12)   # mismo lienzo que las capas del juego (1592x1318)
canvas = [sc.render.resolution_x, sc.render.resolution_y]
def only(keep, path):
    keep = set(keep)
    for o in sc.objects:
        if o.type == "MESH" and not (o in set(K(rack_bad))):
            o.visible_camera = o in keep
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

a = None
for pose in ("teclea_a", "teclea_b", "estres"):
    if a:
        for o in reversed(K(a)): bpy.data.objects.remove(o, do_unlink=True)
    a = build_alex(pose, SEAT, fem=True); bpy.context.view_layer.update()
    only(K(a) + K(silla), f"{OUT}/2x/alexa_{pose}.png")

# de pie (referencia grande, misma escala que la de Alex: x4)
for o in reversed(K(a)): bpy.data.objects.remove(o, do_unlink=True)
for o in sc.objects:
    if o.type == "MESH": o.visible_camera = True
stand = build_alex("pie", (0, 0, 0), fem=True); stand.rotation_euler = (0, 0, math.radians(120)); stand.location = (3.2, 3.6, 0)
bpy.context.view_layer.update()
keep = set(K(stand))
for o in sc.objects:
    if o.type in ("MESH", "EMPTY"): o.hide_render = o not in keep
frame(K(stand), 4); sc.render.filepath = f"{OUT}/ref/alexa_de_pie.png"; bpy.ops.render.render(write_still=True)
frame(K(stand), 2); sc.render.filepath = f"{OUT}/2x/alexa_de_pie.png"; bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/alexa.blend")
json.dump({"canvas": canvas}, open(f"{OUT}/meta.json", "w"))
print("ALEXA OK", canvas)
