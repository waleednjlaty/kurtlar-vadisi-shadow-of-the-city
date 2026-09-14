import bpy,pathlib
SRC=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(SRC/'existing_mod_reference.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH')
for i,m in enumerate(o.data.materials):
    ids={vi for p in o.data.polygons if p.material_index==i for vi in p.vertices};v=[o.data.vertices[j].co for j in ids]
    print(m.name,[(min(p[k] for p in v),max(p[k] for p in v)) for k in range(3)])
