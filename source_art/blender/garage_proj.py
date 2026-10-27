import bpy, math, json, sys
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath="/home/claude/kit/out/kit_piloto_garage.blend")
sc=bpy.context.scene; cam=bpy.data.objects["IsoCam"]
PPM=128/math.sqrt(2); R=cam.matrix_world.to_3x3()
RIGHT,UP,FWD=R@Vector((1,0,0)),R@Vector((0,1,0)),R@Vector((0,0,-1))
O=bpy.data.objects
def K(r): return [r]+list(r.children_recursive)
objs=K(O["Cuarto_Garage"])+K(O["Escritorio_PC"])+K(O["Rack_OK"])
pts=[o.matrix_world@Vector(c) for o in objs if o.type=="MESH" for c in o.bound_box]
xs=[p.dot(RIGHT) for p in pts]; ys=[p.dot(UP) for p in pts]
scale,pad=2,12
cx,cy=(min(xs)+max(xs))/2,(min(ys)+max(ys))/2
w=int(math.ceil(((max(xs)-min(xs))*PPM*scale+2*pad)/2)*2); h=int(math.ceil(((max(ys)-min(ys))*PPM*scale+2*pad)/2)*2)
json.dump({"cx":cx,"cy":cy,"W":w,"H":h,"ppm":PPM*scale,"right":list(RIGHT),"up":list(UP)},open("/home/claude/kit/office/garage_proj.json","w"))
print("GPROJ",w,h)
