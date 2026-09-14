import bpy,sys,pathlib,importlib.util,json
from mathutils import Vector,Matrix
SRC=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('dragonff',SRC/'tools/DragonFF-master/__init__.py',submodule_search_locations=[str(SRC/'tools/DragonFF-master')]); mod=importlib.util.module_from_spec(spec);sys.modules['dragonff']=mod;spec.loader.exec_module(mod);mod.register()
bpy.ops.wm.open_mainfile(filepath=str(SRC/'existing_mod_reference.blend'))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH'); arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
report={'mesh_matrix':[list(r) for r in mesh.matrix_world],'arm_matrix':[list(r) for r in arm.matrix_world],'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),'materials':[m.name for m in mesh.data.materials],'bones':[dict(name=b.name,parent=b.parent.name if b.parent else None,props=dict(b.items()),head=list(b.head_local),matrix=[list(r) for r in b.matrix_local]) for b in arm.data.bones]}
coords=[mesh.matrix_world@v.co for v in mesh.data.vertices]; report['bounds']=[(min(v[i] for v in coords),max(v[i] for v in coords)) for i in range(3)]
(SRC/'existing_inspection.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
scene=bpy.context.scene; scene.render.engine='CYCLES';scene.cycles.samples=16;scene.world.color=(.15,.15,.15)
camdata=bpy.data.cameras.new('Review');cam=bpy.data.objects.new('Review',camdata);scene.collection.objects.link(cam)
up=Vector((1,0,0)) if (report['bounds'][0][1]-report['bounds'][0][0])>1.7 else Vector((0,0,1))
target=(Vector(tuple(a for a,b in report['bounds']))+Vector(tuple(b for a,b in report['bounds'])))*.5
cam.location=target+Vector((0,4,.3));back=(cam.location-target).normalized();right=up.cross(back).normalized();realup=back.cross(right);cam.rotation_euler=Matrix((right,realup,back)).transposed().to_euler();camdata.type='ORTHO';camdata.ortho_scale=2.3;scene.camera=cam
for name,pos,power in [('Key',(2,4,3),550),('Fill',(-1,2,-3),300)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=4;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.render.filepath=str(SRC/'existing_preview.png');bpy.ops.render.render(write_still=True)
