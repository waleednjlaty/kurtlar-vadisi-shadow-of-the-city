import bpy,sys,pathlib,importlib.util,json,math
from mathutils import Vector,Quaternion
SRC=pathlib.Path(__file__).resolve().parents[1];ROOT=SRC.parents[1];OUT=ROOT/'KurtlarVadisi/staging/skins'
spec=importlib.util.spec_from_file_location('dragonff',SRC/'tools/DragonFF-master/__init__.py',submodule_search_locations=[str(SRC/'tools/DragonFF-master')]);addon=importlib.util.module_from_spec(spec);sys.modules['dragonff']=addon;spec.loader.exec_module(addon);addon.register()
from dragonff.gtaLib import dff,txd
from dragonff.ops import dff_importer,txd_importer
original=dff.dff();original.load_file(str(SRC/'references/original/mafboss.dff'))
exported=dff.dff();exported.load_file(str(OUT/'polat.dff'))
texture=txd.txd();texture.load_file(str(OUT/'polat.txd'))
def hierarchy(model):
    frames=model.clumps[0].frame_list
    return sorted([(f.name,f.bone_data.header.id,frames[f.parent].bone_data.header.id if f.parent>=0 and frames[f.parent].bone_data else None,[(b.id,b.index,b.type) for b in f.bone_data.bones]) for f in frames if f.bone_data],key=lambda row:row[1])
if hierarchy(original)!=hierarchy(exported):
    print('ORIGINAL HIERARCHY',hierarchy(original));print('EXPORTED HIERARCHY',hierarchy(exported))
assert hierarchy(original)==hierarchy(exported),'HAnim names, IDs or hierarchy differs'
assert len(exported.clumps)==1
geos=exported.clumps[0].geometry_list;assert len(geos)==1
geo=geos[0];skin=geo.extensions['skin'];origskin=original.clumps[0].geometry_list[0].extensions['skin']
assert skin.num_bones==origskin.num_bones==32
assert len(skin.vertex_bone_weights)==len(geo.vertices)
assert all(abs(sum(w)-1)<1e-4 and all(0<=x<=1 for x in w) for w in skin.vertex_bone_weights)
assert all(0<=i<32 for inds in skin.vertex_bone_indices for i in inds)
error=max(abs(a-b) for m,n in zip(skin.bone_matrices,origskin.bone_matrices) for r,s in zip(m,n) for a,b in zip(r,s))
assert error<.001,('Bind matrix mismatch',error)
names={t.name for t in texture.native_textures};used={t.name for m in geo.materials for t in m.textures}
assert names==used,(names,used)
assert all(t.width in [128,512,1024] and t.height in [128,512,1024] for t in texture.native_textures)
report=dict(hierarchy_exact=True,bind_matrix_max_error=error,bones=32,vertices=len(geo.vertices),triangles=len(geo.triangles),weights_normalized=True,texture_names_match=True,textures=sorted(names),gameplay_tested=False)
(SRC/'export_validation.json').write_text(json.dumps(report,indent=2));print(report)
# Inspect the exported files through a fresh DragonFF import, not just the source mesh.
bpy.ops.wm.open_mainfile(filepath=str(SRC/'polat.blend'))
for obj in list(bpy.context.scene.objects):
    if obj.type in ['MESH','ARMATURE','EMPTY']: bpy.data.objects.remove(obj,do_unlink=True)
images=txd_importer.import_txd(dict(file_name=str(OUT/'polat.txd'),skip_mipmaps=True,pack=True)).images
dff_importer.import_dff(dict(file_name=str(OUT/'polat.dff'),txd_images=images,image_ext='PNG',connect_bones=False,use_mat_split=True,remove_doubles=False,create_backfaces=False,group_materials=True,import_normals=True,materials_naming='TEX'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bones={b.bone['bone_id']:b for b in arm.pose.bones}
poses={'standing':{},'walk':{41:('z',25),51:('z',-22),42:('z',-20),52:('z',-5)},'run':{41:('z',50),51:('z',-35),42:('z',-70),52:('z',-25),33:('z',-70),23:('z',-70)},'arm_raise':{32:('y',-70),33:('z',-30)},'pistol_pose':{32:('z',-65),22:('z',-65),33:('z',-35),23:('z',-35)},'crouch':{41:('z',65),51:('z',65),42:('z',-100),52:('z',-100),2:('z',-25)}}
folder=SRC/'pose_checks';folder.mkdir(exist_ok=True)
scene=bpy.context.scene;scene.cycles.samples=12;scene.render.resolution_x=720;scene.render.resolution_y=800
results={}
for name,rotations in poses.items():
    for bone in arm.pose.bones: bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion()
    for bid,(axis,angle) in rotations.items():
        bone=bones[bid];world=Vector((0,0,1) if axis=='z' else (0,1,0));local=bone.bone.matrix_local.to_quaternion().inverted()@world
        bone.rotation_quaternion=Quaternion(local,math.radians(angle))
    bpy.context.view_layer.update()
    ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());data=ev.to_mesh()
    assert all(math.isfinite(c) for v in data.vertices for c in v.co)
    bounds=[(min(v.co[i] for v in data.vertices),max(v.co[i] for v in data.vertices)) for i in range(3)]
    assert all(b-a<3 for a,b in bounds),('Exploding mesh',name,bounds)
    results[name]={'finite_coordinates':True,'bounds':bounds,'type':'approximate stress pose, not GTA animation playback'}
    ev.to_mesh_clear();scene.render.filepath=str(folder/f'{name}.png');bpy.ops.render.render(write_still=True)
(folder/'results.json').write_text(json.dumps(results,indent=2))
print('Export and six approximate pose checks passed')
