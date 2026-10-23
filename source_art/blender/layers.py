"""Renderiza capas para componer a Alex: escena sin respaldo + respaldo solo (misma cámara)."""
import bpy, sys
OUT = sys.argv[1]
bpy.ops.wm.open_mainfile(filepath=f"{OUT}/kit_piloto_garage.blend")
sc = bpy.context.scene
silla = bpy.data.objects["Silla"]
respaldo = [o for o in silla.children if o.name.startswith("Respaldo")]
rack_bad = bpy.data.objects["Rack_Saturado"]
bad = set([rack_bad] + list(rack_bad.children_recursive))
rack_ok = bpy.data.objects["Rack_OK"]
ok = set([rack_ok] + list(rack_ok.children_recursive))

def render(path, visible):
    for o in sc.objects:
        if o.type in ("MESH", "EMPTY"): o.hide_render = not visible(o)
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

for tag, hide_rack, show_rack, loc in [("", bad, ok, None), ("_saturado", ok, bad, rack_ok.location.copy())]:
    if loc is not None: rack_bad.location = loc
    render(f"{OUT}/capa_escena{tag}.png", lambda o: o not in hide_rack and o not in respaldo)
render(f"{OUT}/capa_respaldo.png", lambda o: o in respaldo)
print("CAPAS OK")
