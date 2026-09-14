import bpy, sys, pathlib, importlib.util, json, hashlib, struct
from mathutils import Vector, Matrix
SRC=pathlib.Path(__file__).resolve().parents[1];REV=SRC/'revisions/face-posture-20260912'
spec=importlib.util.spec_from_file_location('dragonff',SRC/'tools/DragonFF-master/__init__.py',submodule_search_locations=[str(SRC/'tools/DragonFF-master')]);addon=importlib.util.module_from_spec(spec);sys.modules['dragonff']=addon;spec.loader.exec_module(addon);addon.register()
from dragonff.ops import dff_importer,txd_importer,txd_exporter
from dragonff.gtaLib import txd
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
im=bpy.data.images.load(str(REV/'textures/polat_face_generated.png'));im.scale(1024,1024);im.name='PA_Face';im.filepath_raw=str(REV/'textures/PA_Face.png');im.file_format='PNG';im.save();im.pack()
# Replace only the PA_Face native texture chunk. Other chunks remain byte-for-byte identical.
data=(REV/'backup/polat.txd').read_bytes();root_id,root_len,version=struct.unpack_from('<III',data)
assert root_id==22 and root_len+12==len(data)
native=txd_exporter.txd_exporter._create_texture_native_from_image(im,'PA_Face')
container=txd.txd();container.native_textures=[native];container.device_id=txd.DeviceType.DEVICE_D3D9
single=container.write_memory(0x36003)
def chunks(buf,start,end):
    while start<end:
        cid,size,ver=struct.unpack_from('<III',buf,start);stop=start+12+size
        assert stop<=end
        yield cid,buf[start:stop]
        start=stop
new_chunk=next(b for cid,b in chunks(single,12,len(single)) if cid==21)
parts=[];changed=0;hashes=[]
for cid,chunk in chunks(data,12,len(data)):
    if cid==21:
        # Native struct: chunk header (12), struct header (12), platform/filter (8), name (32).
        name=chunk[32:64].split(b'\0')[0].decode('ascii')
        if name=='PA_Face':parts.append(new_chunk);changed+=1
        else:parts.append(chunk);hashes.append({'name':name,'sha256':hashlib.sha256(chunk).hexdigest()})
    else:parts.append(chunk)
assert changed==1
body=b''.join(parts);output=struct.pack('<III',22,len(body),version)+body
(REV/'polat.txd').write_bytes(output)
check=txd.txd();check.load_file(str(REV/'polat.txd'))
assert len(check.native_textures)==6 and any(t.name=='PA_Face' and t.width==1024 and t.height==1024 for t in check.native_textures)
images=txd_importer.import_txd(dict(file_name=str(REV/'polat.txd'),skip_mipmaps=True,pack=True)).images
for name,ims in list(images.items()):images[name.lower()]=ims;images[name.capitalize()]=ims
# Merge coincident importer vertices for the Blender editing copy only. The installed DFF is not re-exported.
dff_importer.import_dff(dict(file_name=str(REV/'backup/polat.dff'),txd_images=images,image_ext='PNG',connect_bones=False,use_mat_split=True,remove_doubles=True,create_backfaces=False,group_materials=True,import_normals=True,materials_naming='TEX'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.world.color=(.16,.16,.16)
target=Vector((.73,0,0));cd=bpy.data.cameras.new('Face review');cam=bpy.data.objects.new('Face review',cd);scene.collection.objects.link(cam);cam.location=target+Vector((0,4,0));cd.type='ORTHO';cd.ortho_scale=.46;scene.camera=cam
def point_cam():
    back=(cam.location-target).normalized();right=Vector((1,0,0)).cross(back).normalized();up=back.cross(right);cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler()
point_cam()
for name,pos,power in [('Key',(2,4,3),400),('Fill',(-1,2,-3),200)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=4;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard'
bpy.ops.wm.save_as_mainfile(filepath=str(REV/'polat.blend'))
scene.render.filepath=str(REV/'previews/after_front.png');bpy.ops.render.render(write_still=True)
cam.location=target+Vector((0,4,2));point_cam();scene.render.filepath=str(REV/'previews/after_angle.png');bpy.ops.render.render(write_still=True)
# Before preview uses the same importer cleanup, camera, geometry, and lighting.
original=bpy.data.images.load(str(REV/'textures/original_PA_Face.png'))
for mat in bpy.data.materials:
    if mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type=='TEX_IMAGE' and n.image and 'PA_Face' in n.image.name:n.image=original
scene.render.filepath=str(REV/'previews/before_angle_clean.png');bpy.ops.render.render(write_still=True)
cam.location=target+Vector((0,4,0));point_cam();scene.render.filepath=str(REV/'previews/before_front_clean.png');bpy.ops.render.render(write_still=True)
(REV/'face_validation.json').write_text(json.dumps({'new_face_size':[1024,1024],'textures_unchanged':hashes,'original_dff_sha256':hashlib.sha256((REV/'backup/polat.dff').read_bytes()).hexdigest(),'dff_reexported':False,'txd_names':[t.name for t in check.native_textures]},indent=2))
print('FACE_REVISION_PASS')
