import bpy,bmesh,pathlib,json,collections
SRC=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(SRC/'polat.blend'))
o=next(o for o in bpy.context.scene.objects if o.type=='MESH');bm=bmesh.new();bm.from_mesh(o.data)
for idx,mat in enumerate(o.data.materials):
    faces=[f for f in bm.faces if f.material_index==idx];edges={e for f in faces for e in f.edges}
    print(mat.name,'faces',len(faces),'edges',dict(collections.Counter(len(e.link_faces) for e in edges)),'bad area',sum(f.calc_area()<1e-12 for f in faces))
print('nonmanifold examples',[(list(e.verts[0].co),len(e.link_faces)) for e in bm.edges if len(e.link_faces)>2][:15])
