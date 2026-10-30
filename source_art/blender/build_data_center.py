"""
Data center (etapa 3 · Enterprise) — Server Flow 2D.
Cuarto 12x12 m. Conserva escritorio, silla, puerta y avatar en la MISMA posición del mundo que el
garage/oficina (se reutilizan con (dx,dy)). Nuevo: bay de 9 racks (reutiliza el sprite de rack del
garage x9, solo cambia la posición), partición de vidrio (decorativa) y placa de Firewall (2 estados).
Renderiza a 2x: piso (3 variantes), pared_izq (10), pared_der (10), vidrio (1), firewall (2 estados),
y escribe data_center_meta.json con proyección, cuadrícula, reutilizados_del_garage (desk/door/avatar +
9 racks) y zonas reservadas para el catálogo extra del equipo.
completar_meta() agrega lo que usa el juego: lado de servidores ocupado, tramos prohibidos de pared,
ysort_m y fijos.racks (rack_id → servidor).
Uso: python3 build_data_center.py <salida> <menu.png>
"""
import sys, math, json, os
import bpy
from mathutils import Vector
OUTDIR = sys.argv[1]; MENU = sys.argv[2]
SRC = open("/home/claude/kit/build_kit.py").read()
sys.argv = [sys.argv[0], OUTDIR, MENU]
exec(SRC[:SRC.index("room = build_room()")])
sc.eevee.taa_render_samples = 16

N = 12
P3 = dict(piso_dc="#394153", junta_dc="#2b3243", vidrio="#9fd3f2", fw_off="#2a3242", fw_on="#5aa9ff")
M["piso_dc"] = mat("piso_dc", P3["piso_dc"], 0.55)
M["junta_dc"] = mat("junta_dc", P3["junta_dc"], 0.6)
M["vidrio_dc"] = mat("vidrio_dc", "#8cb8cc", 0.08, 0.0)
_vb = M["vidrio_dc"].node_tree.nodes["Principled BSDF"]
if "Alpha" in _vb.inputs: _vb.inputs["Alpha"].default_value = 0.22
M["vidrio_dc"].blend_method = "BLEND"
M["fw_panel"] = mat("fw_panel", "#1f2c3f", 0.5)
M["fw_led"] = mat("fw_led_e", P3["fw_off"], 0.4, 0.0)

def build_data_center():
    r = group("DataCenter")
    cube("Piso", (N/2, N/2, -0.05), (N, N, 0.1), M["piso_dc"], 0, r)
    # juntas de piso técnico (losetas de 1 m, a diferencia del laminado de la oficina)
    for i in range(1, N):
        cube("Junta", (N/2, i, 0.001), (N, 0.01, 0.002), M["junta_dc"], 0, r)
        cube("JuntaV", (i, N/2, 0.001), (0.01, N, 0.002), M["junta_dc"], 0, r)
    cube("Pared_Izq", (-0.06, N/2, 1.6), (0.12, N, 3.2), M["pared_izq"], 0, r)
    cube("Pared_Der", (N/2, N + 0.06, 1.6), (N, 0.12, 3.2), M["pared_der"], 0, r)
    cube("Zoclo_Izq", (0.01, N/2, 0.06), (0.04, N, 0.12), M["zoclo"], 0, r)
    cube("Zoclo_Der", (N/2, N - 0.01, 0.06), (N, 0.04, 0.12), M["zoclo"], 0, r)
    # puerta: misma posición que garage/oficina
    cube("Puerta", (0.02, 4.9, 1.05), (0.05, 1.0, 2.1), M["puerta"], 0.01, r)
    cube("Manija", (0.07, 4.5, 1.0), (0.05, 0.08, 0.05), M["manija"], 0.005, r)
    return r

def build_vidrio():
    # partición de vidrio entre el escritorio y el bay de racks (solo decorativa, con hueco visual)
    r = group("Vidrio")
    x0 = 5.4
    for (y0, y1) in [(0.3, 5.0), (7.0, 11.7)]:
        cube("Panel", ((y0+y1)/2*0+x0, (y0+y1)/2, 1.95), (0.03, y1-y0, 3.5), M["vidrio_dc"], 0.002, r)
    cube("Marco_Sup", (x0, N/2, 3.62), (0.05, N-0.6, 0.08), M["marco"], 0, r)
    return r

def build_firewall():
    # placa de Firewall montada en la pared trasera del bay (pared_der, y=N), no en un rack
    r = group("Firewall")
    cube("Panel", (7.6, N-0.04, 1.9), (0.9, 0.08, 0.9), M["fw_panel"], 0.01, r)
    for i in range(3):
        cube("LED", (7.25 + i*0.3, N-0.1, 2.25), (0.14, 0.03, 0.08), M["fw_led"], 0, r)
    return r

room = build_data_center()
desk = build_desk((0.15, 1.2, 0))
chair = build_chair((1.62, 2.15, 0))
vidrio = build_vidrio()
firewall = build_firewall()

# 9 racks (solo para encuadre/sombra; el sprite real se reutiliza del garage)
# posiciones alineadas a múltiplos de 0.125 m respecto a RACK_REF (0.9, 5.15) para que el
# delta de cada rack caiga EXACTO en múltiplos de 8 px (sin redondeo, 0 px de desvío).
RACK_XS = [7.025, 8.15, 9.275]; RACK_YS = [7.025, 9.025, 11.025]
racks = []
ri = 1
for ry in RACK_YS:
    for rx in RACK_XS:
        racks.append((f"Rack_{ri}", build_rack((rx, ry, 0), M["led_ok"], f"Rack_{ri}")))
        ri += 1

# avatar (solo para que proyecte sombra en el piso, igual que en la oficina)
with bpy.data.libraries.load("/home/claude/kit/out_alex/garage_con_alex.blend") as (src, dst):
    dst.objects = list(src.objects)
alex_root = next(o for o in dst.objects if o and o.name.startswith("Alex_teclea_a"))
pool = [o for o in dst.objects if o]
alex_objs = [alex_root]
changed = True
while changed:
    changed = False
    for o in pool:
        if o.parent in alex_objs and o not in alex_objs:
            alex_objs.append(o); changed = True
for o in alex_objs: sc.collection.objects.link(o)

# ---------------- cámara (misma orientación que garage/oficina) ----------------
cam_data = bpy.data.cameras.new("IsoCam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("IsoCam", cam_data); sc.collection.objects.link(cam); sc.camera = cam
cam.rotation_euler = (math.radians(60), 0, math.radians(45))
bpy.context.view_layer.update()
R = cam.matrix_world.to_3x3()
RIGHT, UP, FWD = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
SCALE = 2; PPM2 = PPM * SCALE
def K(r): return [r] + list(r.children_recursive)
all_roots = [room, desk] + [rk for _, rk in racks] + [vidrio, firewall]
pts = [o.matrix_world @ Vector(c) for rt in all_roots for o in K(rt) if o.type == "MESH" for c in o.bound_box]
xs = [p.dot(RIGHT) for p in pts]; ys = [p.dot(UP) for p in pts]
cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
pad = 12
W = int(math.ceil(((max(xs) - min(xs)) * PPM2 + 2 * pad) / 8) * 8)
H = int(math.ceil(((max(ys) - min(ys)) * PPM2 + 2 * pad) / 8) * 8)
W += 8; H += 8
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

RACK_REF = (0.9, 5.15, 0)  # ancla del rack en el garage (mismo punto que usó la oficina)
rack_deltas = {}
ri = 1
for ry in RACK_YS:
    for rx in RACK_XS:
        move = (rx - RACK_REF[0], ry - RACK_REF[1], 0)
        rack_deltas[f"rack_{ri} (fijos/rack_ok|rack_saturado)"] = delta(move, RACK_REF)
        ri += 1

ALL = [o for o in sc.objects if o.type == "MESH"]
LAYERS = {
    "piso": [o for o in room.children if o.name.startswith(("Piso", "Junta"))],
    "pared_izq": [o for o in room.children if o.name.startswith(("Pared_Izq", "Zoclo_Izq"))],
    "pared_der": [o for o in room.children if o.name.startswith(("Pared_Der", "Zoclo_Der"))],
    "vidrio": [o for o in K(vidrio) if o.type == "MESH"],
    "firewall": [o for o in K(firewall) if o.type == "MESH"],
}
def only(objs, path):
    keep = set(objs)
    for o in ALL: o.visible_camera = o in keep
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
def setcol(m, hx):
    bpy.data.materials[m].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hexrgb(hx)
def setemit(m, strength, hx=None):
    b = bpy.data.materials[m].node_tree.nodes["Principled BSDF"]
    if hx: b.inputs["Emission Color"].default_value = hexrgb(hx)
    b.inputs["Emission Strength"].default_value = strength

PAL_PISO = [("tecnico_gris", "Técnico gris", "#394153", "#2b3243"), ("tecnico_azul", "Técnico azul", "#2b3a52", "#1f2a3c"),
            ("antiestatico", "Antiestático", "#3a3f4a", "#2c303a")]
PARED = json.load(open("/home/claude/kit/out_custom/paleta.json"))["paleta"]["pared"]

for d in ("piso", "pared_izq", "pared_der", "vidrio", "firewall"): os.makedirs(f"{OUTDIR}/2x/{d}", exist_ok=True)
for vid, name, hx, seam in PAL_PISO:
    setcol("piso_dc", hx); setcol("junta_dc", seam); only(LAYERS["piso"], f"{OUTDIR}/2x/piso/{vid}.png")
for v in PARED:
    setcol("pared_izq", v["color"]); only(LAYERS["pared_izq"], f"{OUTDIR}/2x/pared_izq/{v['id']}.png")
    setcol("pared_der", v["color"]); only(LAYERS["pared_der"], f"{OUTDIR}/2x/pared_der/{v['id']}.png")
only(LAYERS["vidrio"], f"{OUTDIR}/2x/vidrio/vidrio.png")
setemit("fw_led_e", 0.0, P3["fw_off"]); only(LAYERS["firewall"], f"{OUTDIR}/2x/firewall/apagado.png")
setemit("fw_led_e", 5.0, P3["fw_on"]); only(LAYERS["firewall"], f"{OUTDIR}/2x/firewall/activo.png")

# ---------------- metadatos ----------------
ex = [RIGHT.x * PPM2, -UP.x * PPM2]; ey = [RIGHT.y * PPM2, -UP.y * PPM2]; ez = [RIGHT.z * PPM2, -UP.z * PPM2]
origin = proj((0, 0, 0))
reutilizados = {
    "nota": "Usar el MISMO sprite del garage y sumar (dx, dy) a su offset del garage (lienzo 2x).",
    "mesa/*": delta(), "puerta/*": delta(), "alex/*": delta(), "alexa/*": delta(),
}
reutilizados.update(rack_deltas)
meta = {
  "room": "data_center", "canvas": [W, H], "escala_nodo": 0.5,
  "proyeccion": {"nota": "pixel(lienzo 2x) = origen + x*ex + y*ey + z*ez  (x, y, z en metros del mundo)",
                 "origen": [round(origin[0], 3), round(origin[1], 3)], "ex": ex, "ey": ey, "ez": ez},
  "cuadricula": {"celda_m": 0.5, "x": [0, N], "y": [0, N],
                 "ocupado_m": [{"id": "escritorio_y_silla", "x": [0.0, 2.0], "y": [1.0, 3.6]},
                               {"id": "puerta", "x": [0.0, 1.2], "y": [4.3, 5.5]},
                               {"id": "vidrio", "x": [5.3, 5.5], "y": [0.0, N]}],
                 "zonas_catalogo_extra": [
                     {"id": "piso_1", "tipo": "piso", "x": [2.3, 3.9], "y": [4.3, 5.9], "nota": "piso/tapete frente al escritorio"}
                 ],
                 "nota": "zonas ocupadas en metros (no se puede colocar decoración ahí). zonas_catalogo_extra reservadas para las referencias personales del equipo; sin objetos todavía."},
  "reutilizados_del_garage": reutilizados,
  "fijos": {
      "nota": "Objetos propios del data center, no se reutilizan de otro cuarto; van siempre en esta posición.",
      "vidrio": {"sprite": "vidrio/vidrio.png", "pos_m": [5.4, 6.0, 0], "nota": "decorativo, no bloquea el paso, no admite objetos del catálogo pegados"},
      "firewall": {"apagado": "firewall/apagado.png", "activo": "firewall/activo.png", "pos_m": [7.6, 12.0, 1.45], "nota": "mejora comprable en la consola; activo cuando firewall_activo=true"},
  },
  "paleta_piso": [dict(id=v[0], nombre=v[1], color=v[2]) for v in PAL_PISO],
}


def completar_meta(meta, rack_xs, rack_ys, n):
    """Lo que el juego necesita además de la geometría (antes se completaba a mano en el JSON).
    No usa bpy: tests/ no lo corre, pero se puede revisar aparte con los deltas del JSON."""
    grid = meta["cuadricula"]
    # El bay bloquea solo la huella de los racks (0.7 x 0.7 m desde su ancla, ver build_rack): el pasillo
    # entre el vidrio y los racks sí se decora.
    rack_size = 0.7
    grid["ocupado_m"] = [zone for zone in grid["ocupado_m"] if zone["id"] != "bay_racks"]
    grid["ocupado_m"].append({
        "id": "bay_racks",
        "x": [min(rack_xs), round(max(rack_xs) + rack_size, 3)],
        "y": [min(rack_ys), round(max(rack_ys) + rack_size, 3)],
    })
    grid["nota"] = (
        "zonas ocupadas en metros (no se puede colocar decoración ahí). bay_racks es el rectángulo justo de los "
        "9 racks; el pasillo entre el vidrio y los racks sí se decora. zonas_catalogo_extra reservadas para las "
        "referencias personales del equipo; sin objetos todavía."
    )

    # Zonas de pared del catálogo extra: a los lados del escritorio (boceto aprobado), en los huecos
    # del muro izquierdo entre el borde, el monitor (y 1.1–3.5) y la puerta (y 4.3–5.5).
    grid["zonas_catalogo_extra"] = [
        {"id": "pared_izq_1", "tipo": "pared", "x": [0.0, 0.3], "y": [0.0, 1.1], "nota": "a un lado del escritorio, antes del monitor"},
        {"id": "pared_izq_2", "tipo": "pared", "x": [0.0, 0.3], "y": [3.5, 4.3], "nota": "al otro lado del escritorio, entre el monitor y la puerta"},
    ] + [zone for zone in grid["zonas_catalogo_extra"] if zone["tipo"] != "pared"]

    # La placa está en la pared, atrás de los racks: se dibuja antes que ellos.
    meta["orden_capas"] = ["piso", "pared_izq", "pared_der", "puerta", "vidrio", "firewall", "racks", "decoracion (y-sort)", "mesa", "avatar"]

    # Los (dx, dy) de los racks deben caer exactos en múltiplos de 8 (RACK_XS/RACK_YS están alineados).
    for key, value in meta["reutilizados_del_garage"].items():
        if key.startswith("rack_") and any(v % 8.0 != 0.0 for v in value):
            raise ValueError("%s no cae en múltiplos de 8: %s" % (key, value))

    # Centro de la huella para el y-sort con la decoración del pasillo.
    ysort = {"nota": "Centro de la huella (metros) de la mesa con el avatar y de cada rack.", "mesa": [1.0, 2.3]}
    racks = []
    index = 1
    for ry in rack_ys:
        for rx in rack_xs:
            rack_id = "rack_%d" % index
            ysort[rack_id] = [round(rx + rack_size / 2, 3), round(ry + rack_size / 2, 3)]
            racks.append({"rack_id": rack_id, "servidor": index})
            index += 1
    meta["ysort_m"] = ysort

    meta["fijos"]["racks"] = {
        "nota": "Bay fijo de 9 racks (no es decoración). 'servidor' es el número de servidor web (1 = el primero) "
        "cuyo estado muestra el rack: se pone rojo cuando ese servidor se satura. Sin ese servidor, el rack se ve normal.",
        "lista": racks,
    }

    meta["tramos_prohibidos_pared"] = {
        "nota": "Zonas de cada muro donde no se puede colgar decoración: 'tramo' a lo largo del muro y 'z' en altura "
        "(metros). der = pared y=12 (eje x), izq = pared x=0 (eje y). Los muros miden 3.2 m.",
        "der": [{"id": "bay", "tramo": [5.3, float(n)], "z": [0.0, 3.2]}],
        "izq": [
            {"id": "monitor", "tramo": [1.1, 3.5], "z": [0.75, 1.6]},
            {"id": "puerta", "tramo": [4.3, 5.5], "z": [0.0, 2.15]},
        ],
    }
    return meta


completar_meta(meta, RACK_XS, RACK_YS, N)
json.dump(meta, open(f"{OUTDIR}/data_center_meta.json", "w"), ensure_ascii=False, indent=1)
for o in ALL: o.visible_camera = True
bpy.ops.wm.save_as_mainfile(filepath=f"{OUTDIR}/data_center.blend")
print("DATA CENTER OK", W, H)
