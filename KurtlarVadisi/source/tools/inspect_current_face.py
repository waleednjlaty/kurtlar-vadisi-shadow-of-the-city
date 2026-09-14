import bpy, sys, pathlib, importlib.util, json, hashlib
from mathutils import Vector, Matrix
SRC=pathlib.Path(__file__).resolve().parents[1]
REV=SRC/'revisions/face-posture-20260912'
spec=importlib.util.spec_from_file_location('dragonff',SRC/'tools/DragonFF-master/__init__.py',submodule_search_locations=[str(SRC/'tools/DragonFF-master')])
addon=importlib.util.module_from_spec(spec);sys.modules['dragonff']=addon;spec.loader.exec_module(addon);addon.register()
from dragonff.ops import dff_importer, txd_importer
from dragonff.gtaLib import dff, txd
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
images=txd_importer.import_txd(dict(file_name=str(REV/'backup/polat.txd'),skip_mipmaps=True,pack=True)).images
report={'textures':{},'objects':[]}
for name,imgs in list(images.items()):
    im=imgs[0];im.filepath_raw=str(REV/'textures'/f'original_{name}.png');im.file_format='PNG';im.save()
    report['textures'][name]=list(im.size)
    images[name.lower()]=imgs;images[name.capitalize()]=imgs
dff_importer.import_dff(dict(file_name=str(REV/'backup/polat.dff'),txd_images=images,image_ext='PNG',connect_bones=False,use_mat_split=True,remove_doubles=False,create_backfaces=False,group_materials=True,import_normals=True,materials_naming='TEX'))
for o in bpy.context.scene.objects:
    if o.type=='MESH':
        report['objects'].append({'name':o.name,'vertices':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'materials':[m.name for m in o.data.materials]})
    if o.type=='ARMATURE':report['bones']=[{'name':b.name,'parent':b.parent.name if b.parent else None,'props':dict(b.items())} for b in o.data.bones]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world.color=(.16,.16,.16)
target=Vector((.73,0,0))
camdata=bpy.data.cameras.new('Face review');cam=bpy.data.objects.new('Face review',camdata);scene.collection.objects.link(cam)
cam.location=target+Vector((0,4,0));back=(cam.location-target).normalized();right=Vector((1,0,0)).cross(back).normalized();up=back.cross(right);cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler();camdata.type='ORTHO';camdata.ortho_scale=.46;scene.camera=cam
for name,pos,power in [('Key',(2,4,3),400),('Fill',(-1,2,-3),200)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=4;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard'
(REV/'current_inspection.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
bpy.ops.wm.save_as_mainfile(filepath=str(REV/'original_current.blend'))
scene.render.filepath=str(REV/'previews/before_front.png');bpy.ops.render.render(write_still=True)
cam.location=target+Vector((0,4,2));back=(cam.location-target).normalized();right=Vector((1,0,0)).cross(back).normalized();up=back.cross(right);cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler()
scene.render.filepath=str(REV/'previews/before_angle.png');bpy.ops.render.render(write_still=True)
