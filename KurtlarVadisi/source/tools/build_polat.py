exec(compile((__import__('pathlib').Path(__file__).parent/'inspect_base.py').read_text(),str(__import__('pathlib').Path(__file__).parent/'inspect_base.py'),'exec'))
import math, bmesh
from mathutils import Vector
from dragonff.ops import dff_exporter, txd_exporter
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
original_bones=[(b.name,b.parent.name if b.parent else None,dict(b.items()),list(sum((list(row) for row in b.matrix_local),[]))) for b in arm.data.bones]
mesh.name='polat'
im=bpy.data.images.load(str(SRC/'textures/polat_atlas_generated.png'))
im.scale(1024,1024)
im.name='polat_atlas'; im.filepath_raw=str(SRC/'textures/polat_atlas.png'); im.file_format='PNG'; im.save(); im.pack()
for mat in mesh.data.materials:
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE': node.image=im; node.label='polat_atlas'
        if node.type=='BSDF_PRINCIPLED': node.inputs['Roughness'].default_value=.8
    mat.diffuse_color=(1,1,1,1)
# Map original atlas islands to the corresponding generated atlas regions.
regions=[((0,.5,0,.58),(0,.393,0,.433)),((.5,1,0,.435),(.393,1,0,.264)),((.5,1,.435,.58),(.393,1,.264,.433)),((0,.414,.58,.78),(0,.337,.433,.68)),((0,.195,.78,1),(0,.182,.68,1)),((.195,.414,.78,1),(.182,.337,.68,1)),((.414,1,.58,1),(.337,1,.433,1))]
uv=mesh.data.uv_layers.active.data
for poly in mesh.data.polygons:
    u=sum(uv[i].uv.x for i in poly.loop_indices)/len(poly.loop_indices)
    t=1-sum(uv[i].uv.y for i in poly.loop_indices)/len(poly.loop_indices)
    old,new=next(((a,b) for a,b in regions if a[0]-.002<=u<=a[1]+.002 and a[2]-.002<=t<=a[3]+.002),regions[-1])
    for i in poly.loop_indices:
        x,y=uv[i].uv; y=1-y
        uv[i].uv=(new[0]+(x-old[0])/(old[1]-old[0])*(new[1]-new[0]),1-(new[2]+(y-old[2])/(old[3]-old[2])*(new[3]-new[2])))
# Preserve armature rest matrices and original vertex groups. Shape in mesh-local axes: X is height.
for v in mesh.data.vertices:
    h,depth,width=v.co
    if h>.60:
        # Wider lower jaw, less bulky cheeks, slightly fuller crown.
        f=math.exp(-((h-.665)/.055)**2)
        v.co.z=width*(1+.07*f)
        if h>.79: v.co.x+=.006*min(1,(h-.79)/.04)
    elif .05<h<.48:
        v.co.z*=1.025
bpy.ops.object.select_all(action='DESELECT'); mesh.select_set(True); bpy.context.view_layer.objects.active=mesh
for mod in list(mesh.modifiers):
    if mod.type!='ARMATURE': mesh.modifiers.remove(mod)
sub=mesh.modifiers.new('Joint surface refinement','SUBSURF'); sub.subdivision_type='SIMPLE'; sub.levels=2
bpy.ops.object.modifier_move_up(modifier=sub.name)
bpy.ops.object.modifier_apply(modifier=sub.name)
# Light relaxation removes subdivision faceting without changing the rig.
sm=mesh.modifiers.new('Surface relaxation','SMOOTH'); sm.factor=.22; sm.iterations=3
bpy.ops.object.modifier_move_up(modifier=sm.name); bpy.ops.object.modifier_apply(modifier=sm.name)
bm=bmesh.new(); bm.from_mesh(mesh.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh.data); bm.free()
for p in mesh.data.polygons: p.use_smooth=True
# Skin format permits at most four normalized influences per vertex.
for v in mesh.data.vertices:
    groups=sorted([(g.group,g.weight) for g in v.groups if g.weight>1e-6],key=lambda x:x[1],reverse=True)
    keep=groups[:4]; total=sum(w for _,w in keep)
    assert total>0, ('unweighted vertex',v.index)
    for gi,w in groups[4:]: mesh.vertex_groups[gi].remove([v.index])
    for gi,w in keep: mesh.vertex_groups[gi].add([v.index],w/total,'REPLACE')
assert original_bones==[(b.name,b.parent.name if b.parent else None,dict(b.items()),list(sum((list(row) for row in b.matrix_local),[]))) for b in arm.data.bones]
out=ROOT/'KurtlarVadisi/staging/skins'; out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
dff_exporter.export_dff(dict(selected=True,export_frame_names=True,exclude_geo_faces=False,mass_export=False,preserve_positions=True,preserve_rotations=True,directory=str(out),version=0x36003,export_coll=False,coll_ext_type='SA',apply_coll_trans=False,from_outliner=False,file_name=str(out/'polat.dff')))
txd_exporter.export_txd(dict(directory=str(out),file_name=str(out/'polat.txd'),version=0x36003,only_used_textures=True))
bm=bmesh.new(); bm.from_mesh(mesh.data)
report=dict(triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons),vertices=len(mesh.data.vertices),bones=len(arm.data.bones),skeleton_unchanged=True,nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),loose_vertices=sum(not v.link_faces for v in bm.verts),max_influences=max(len(v.groups) for v in mesh.data.vertices))
bm.free(); (SRC/'mesh_validation.json').write_text(json.dumps(report,indent=2)); print(report)
# Store presentation cameras separately; only skinned objects were exported above.
scene=bpy.context.scene
coords=[mesh.matrix_world@v.co for v in mesh.data.vertices]
print('WORLD BOUNDS',[(min(v[i] for v in coords),max(v[i] for v in coords)) for i in range(3)])
print('MESH MATRIX',mesh.matrix_world)
center=sum(coords,Vector())/len(coords)
def aim(o,target): o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('Preview'); cam=bpy.data.objects.new('Preview',camdata); scene.collection.objects.link(cam)
cam.location=(2.6,-4,1.4); aim(cam,(0,0,.0)); camdata.type='ORTHO'; camdata.ortho_scale=2.35; scene.camera=cam
for name,pos,power,size in [('Key',(2,-4,4),450,4),('Fill',(-3,-1,2),250,3),('Rim',(0,3,3),350,2)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=pos; aim(obj,(0,0,0))
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.world.color=(.12,.12,.12)
scene.render.resolution_x=900; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'polat.blend'))
scene.render.filepath=str(SRC/'preview.png'); bpy.ops.render.render(write_still=True)
