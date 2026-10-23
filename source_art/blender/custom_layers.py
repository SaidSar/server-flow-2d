"""
Capas de personalización del garage (Server Flow 2D).
Todas las capas se renderizan al MISMO lienzo (encuadre del cuarto completo), así en Godot se apilan
en la misma posición sin cálculos. Las sombras de los demás objetos se hornean en cada capa
(los objetos no visibles para la cámara siguen proyectando sombra).
Render a 2x; la versión 1x se obtiene reduciendo (ver downscale en el script de empaquetado).
Uso: python3 custom_layers.py <kit_out> <salida>
"""
import sys, json, math, os
import bpy
from mathutils import Vector
KIT_OUT, OUT = sys.argv[1], sys.argv[2]
SRC = open("/home/claude/kit/alex3d.py").read()
sys.argv = [sys.argv[0], KIT_OUT, OUT]
exec(SRC[:SRC.index("# ---------------- render helpers")])   # abre el kit, mueve la silla, define build_alex()

os.makedirs(OUT, exist_ok=True)
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
bpy.context.view_layer.update()
SEAT = silla.matrix_world @ Vector((0.0, 0, 0.56))
PALETA = {
  "pared": [("verde_salvia","Verde salvia","#8fa77a"),("gris_calido","Gris cálido","#b9b2a6"),("blanco_hueso","Blanco hueso","#e6e1d4"),
            ("azul_acero","Azul acero","#7d93ad"),("azul_marino","Azul marino","#3e5272"),("terracota","Terracota","#c07a5a"),
            ("mostaza","Mostaza","#d1a646"),("menta","Menta","#9fcdb8"),("lavanda","Lavanda","#a99cc8"),("grafito","Grafito","#4a4f5a")],
  "piso":  [("concreto_gris","Concreto gris","#9aa0a6"),("concreto_calido","Concreto cálido","#b3aa9c"),("concreto_oscuro","Concreto pulido oscuro","#6e747c")],
  "puerta":[("blanca","Blanca","#e8e8e8"),("madera_natural","Madera natural","#b5773f"),("madera_oscura","Madera oscura","#6b4a2f"),
            ("negra","Negro mate","#2b2f36"),("roja","Rojo","#b8433a"),("petroleo","Azul petróleo","#2f6f7a")],
  "mesa":  [("roble","Roble","#b5773f","#8a5a2e"),("nogal","Nogal","#6b4a2f","#4a3220"),("blanca","Blanca","#e9e4d8","#b9b3a6")],
}

def setcol(matname, hexcol):
    m = bpy.data.materials[matname]
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexrgb(hexcol)

O = bpy.data.objects
room = O["Cuarto_Garage"]; desk = O["Escritorio_PC"]; rack_ok = O["Rack_OK"]; rack_bad = O["Rack_Saturado"]
boxes = [O["Caja_Grande"], O["Caja_Chica"], O["Caja_Suelta"]]
rack_bad.location = rack_ok.location.copy()
def K(r): return [r] + list(r.children_recursive)
by = lambda prefix: [o for o in room.children if o.name.startswith(prefix)]
L = {
  "piso": by("Piso") + by("Cylinder") + [o for o in room.children if o.data and o.data.materials and o.data.materials[0].name.startswith("mancha")],
  "pared_izq": by("Pared_Izq") + by("Zoclo_Izq"),
  "pared_der": by("Pared_Der") + by("Zoclo_Der") + by("Pizarron") + by("Trazo"),
  "puerta": by("Puerta") + by("Manija"),
}
L["piso"] = list({o.name: o for o in L["piso"]}.values())
alex = build_alex("teclea_a", SEAT)
bpy.context.view_layer.update()

# encuadre fijo del cuarto completo (2x)
frame(K(room) + K(desk) + K(rack_ok), 2, pad=12)
W, H = sc.render.resolution_x, sc.render.resolution_y

ALL = [o for o in sc.objects if o.type == "MESH"]
def only(objs, path):
    keep = set(objs)
    for o in ALL:
        o.hide_render = False
        o.visible_camera = o in keep
    # el rack que no aplica no debe ni proyectar sombra
    for o in ALL:
        if o in set(K(rack_bad)) and not (keep & set(K(rack_bad))): o.hide_render = True
        if o in set(K(rack_ok)) and (keep & set(K(rack_bad))): o.hide_render = True
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

ALL = [o for o in sc.objects if o.type == "MESH"]
d = f"{OUT}/2x"
for vid, name, hx in PALETA["piso"]:
    setcol("concreto", hx); setcol("mancha", hx);
    # mancha un poco más oscura que el piso
    c = hexrgb(hx); bpy.data.materials["mancha"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = [x * 0.72 for x in c[:3]] + [1]
    only(L["piso"], f"{d}/piso/{vid}.png")
setcol("concreto", PALETA["piso"][0][2])
for vid, name, hx in PALETA["pared"]:
    setcol("pared_izq", hx); only(L["pared_izq"], f"{d}/pared_izq/{vid}.png")
    setcol("pared_der", hx); only(L["pared_der"], f"{d}/pared_der/{vid}.png")
setcol("pared_izq", "#8fa77a"); setcol("pared_der", "#a3bb8c")
for vid, name, hx in PALETA["puerta"]:
    setcol("puerta", hx); only(L["puerta"], f"{d}/puerta/{vid}.png")
setcol("puerta", "#e8e8e8")
for vid, name, hx, leg in PALETA["mesa"]:
    setcol("madera", hx); setcol("madera_osc", leg); only(K(desk), f"{d}/mesa/{vid}.png")
setcol("madera", "#b5773f"); setcol("madera_osc", "#8a5a2e")
only(K(rack_ok), f"{d}/fijos/rack_ok.png")
only(K(rack_bad), f"{d}/fijos/rack_saturado.png")
only(sum((K(b) for b in boxes), []), f"{d}/fijos/cajas.png")
for pose in ("teclea_a", "teclea_b", "estres"):
    if pose != "teclea_a":
        for o in reversed(K(alex)): bpy.data.objects.remove(o, do_unlink=True)
        alex = build_alex(pose, SEAT); bpy.context.view_layer.update()
        ALL = [o for o in sc.objects if o.type == "MESH"]
    only(K(alex) + K(silla), f"{d}/alex/alex_{pose}.png")

json.dump({"canvas_2x": [W, H], "paleta": {k: [dict(id=v[0], nombre=v[1], color=v[2]) for v in vals] for k, vals in PALETA.items()},
           "orden_capas": ["piso", "pared_izq", "pared_der", "puerta", "rack", "mesa", "alex", "cajas"]},
          open(f"{OUT}/paleta.json", "w"), ensure_ascii=False, indent=1)
print("CAPAS LISTAS", W, H)
