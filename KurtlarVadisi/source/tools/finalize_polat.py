import bpy,sys,pathlib,importlib.util,json,bmesh,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
SRC=pathlib.Path(__file__).resolve().parents[1]; ROOT=SRC.parents[1]
spec=importlib.util.spec_from_file_location('dragonff',SRC/'tools/DragonFF-master/__init__.py',submodule_search_locations=[str(SRC/'tools/DragonFF-master')]);addon=importlib.util.module_from_spec(spec);sys.modules['dragonff']=addon;spec.loader.exec_module(addon);addon.register()
from dragonff.ops import dff_exporter,txd_exporter
bpy.ops.wm.open_mainfile(filepath=str(SRC/'original_reference.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
for o in list(bpy.context.scene.objects):
    if o.type=='MESH': bpy.data.objects.remove(o,do_unlink=True)
signature=lambda a:[dict(name=b.name,parent=b.parent.name if b.parent else None,props=dict(b.items()),matrix=[list(r) for r in b.matrix_local]) for b in a.data.bones]
original=signature(arm)
with bpy.data.libraries.load(str(SRC/'existing_mod_reference.blend'),link=False) as (src,dst): dst.objects=src.objects
for o in dst.objects:
    if o is not None: bpy.context.scene.collection.objects.link(o)
mesh=next(o for o in dst.objects if o.type=='MESH'); oldarm=next(o for o in dst.objects if o.type=='ARMATURE')
new_by_id={b['bone_id']:b for b in arm.data.bones}
old_by_name={b.name:b for b in oldarm.data.bones}
weights=[]; mapped={}
for g in mesh.vertex_groups:
    b=old_by_name.get(g.name)
    if b and b['bone_id'] in new_by_id:
        target=new_by_id[b['bone_id']]
        mapped[g.index]=(target.name,target.matrix_local@b.matrix_local.inverted())
for v in mesh.data.vertices:
    keep=sorted([(g.group,g.weight) for g in v.groups if g.group in mapped and g.weight>1e-6],key=lambda a:a[1],reverse=True)[:4]
    assert keep, ('unweighted original',v.index)
    total=sum(w for _,w in keep)
    # Bring every weighted point into the exact original game's rest skeleton.
    v.co=sum(((mapped[gi][1]@v.co)*(w/total) for gi,w in keep),Vector())
    weights.append([(mapped[gi][0],w/total) for gi,w in keep])
mesh.vertex_groups.clear()
for b in arm.data.bones: mesh.vertex_groups.new(name=b.name)
for i,groups in enumerate(weights):
    for name,w in groups: mesh.vertex_groups[name].add([i],w,'REPLACE')
mesh.parent=arm; mesh.matrix_parent_inverse=Matrix.Identity(4);mesh.matrix_world=Matrix.Identity(4)
mesh.modifiers.clear();modifier=mesh.modifiers.new('Original GTA SA skeleton','ARMATURE');modifier.object=arm
bpy.data.objects.remove(oldarm,do_unlink=True);mesh.name='polat'
# Resolve existing Hair/hair mismatch explicitly; preserve original UV coordinates.
texture_sizes={}
for mat in mesh.data.materials:
    for node in mat.node_tree.nodes:
        if node.type=='TEX_IMAGE':
            name=node.label or (node.image.name if node.image else mat.name)
            key=name.lower()
            file=SRC/'textures'/('polat_face_open.png' if key=='pa_face' else f'existing_{name}.png')
            if not file.exists(): file=next(p for p in (SRC/'textures').glob('existing_*.png') if p.stem[9:].lower()==key)
            im=bpy.data.images.load(str(file),check_existing=False)
            size=1024 if key in ['suit','pa_face'] else 512 if key in ['hands','hair'] else 128
            im.scale(size,size);im.name='polat_'+key;im.filepath_raw=str(SRC/'textures'/f'polat_{key}.png');im.file_format='PNG';im.save();im.pack()
            node.image=im;node.label=im.name;texture_sizes[im.name]=list(im.size)
        if node.type=='BSDF_PRINCIPLED': node.inputs['Roughness'].default_value=.85
# Rebuild problematic source surfaces as closed shells, retaining their UVs and skin weights.
bpy.ops.object.select_all(action='DESELECT')
source_mesh=mesh
parts=[]
budgets=[6200,4800,4700,382,382,2200]
voxels=[.006,.0028,.003,.002,.002,.0035]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.025;scene.render.bake.max_ray_distance=.06;scene.render.bake.margin=8
for mi,mat in enumerate(list(source_mesh.data.materials)):
    if mi in [3,4]: continue  # Bake the original eyeballs into the continuous head surface.
    part=source_mesh.copy();part.data=source_mesh.data.copy();bpy.context.scene.collection.objects.link(part);part.modifiers.clear()
    bm=bmesh.new();bm.from_mesh(part.data)
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index!=mi],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(part.data);bm.free()
    part.select_set(True);bpy.context.view_layer.objects.active=part
    if mi not in [3,4]:
        donor=part.copy();donor.data=part.data.copy();bpy.context.scene.collection.objects.link(donor);donor.select_set(False)
        if mi==2:
            # A continuous radial head retopology avoids retaining internal mouth sheets.
            bm=bmesh.new();bm.from_mesh(donor.data);tree=BVHTree.FromBMesh(bm)
            points=[v.co for v in bm.verts];low=Vector(tuple(min(v[i] for v in points) for i in range(3)));high=Vector(tuple(max(v[i] for v in points) for i in range(3)));center=(low+high)*.5;extent=(high-low)*.5
            bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=48,radius=1)
            sphere=bpy.context.object
            for vertex in sphere.data.vertices:
                radial=Vector(tuple(vertex.co[i]*extent[i] for i in range(3))).normalized()
                hit,normal,_,_=tree.ray_cast(center+radial*.7,-radial,1.0)
                vertex.co=hit+normal*.0006 if hit is not None else center+Vector(tuple(vertex.co[i]*extent[i] for i in range(3)))
            part.data=sphere.data.copy();bpy.data.objects.remove(sphere,do_unlink=True);bm.free()
            bpy.ops.object.select_all(action='DESELECT');part.select_set(True);bpy.context.view_layer.objects.active=part
        else:
            shell=part.modifiers.new('Surface thickness for volume','SOLIDIFY');shell.thickness=voxels[mi]*3;shell.offset=-1
            bpy.ops.object.modifier_apply(modifier=shell.name)
            rem=part.modifiers.new('Closed reconstruction','REMESH');rem.mode='VOXEL';rem.voxel_size=voxels[mi];rem.use_smooth_shade=True
            bpy.ops.object.modifier_apply(modifier=rem.name)
        count=sum(len(p.vertices)-2 for p in part.data.polygons)
        if count>budgets[mi]:
            dec=part.modifiers.new('Game triangle budget','DECIMATE');dec.ratio=budgets[mi]/count;bpy.ops.object.modifier_apply(modifier=dec.name)
        caps=bmesh.new();caps.from_mesh(part.data)
        bmesh.ops.holes_fill(caps,edges=[e for e in caps.edges if e.is_boundary],sides=0)
        bmesh.ops.recalc_face_normals(caps,faces=list(caps.faces));caps.to_mesh(part.data);caps.free()
        transfer=part.modifiers.new('Original skin interpolation','DATA_TRANSFER');transfer.object=source_mesh
        transfer.use_vert_data=True;transfer.data_types_verts={'VGROUP_WEIGHTS'};transfer.vert_mapping='POLYINTERP_NEAREST'
        transfer.layers_vgroup_select_src='ALL';transfer.layers_vgroup_select_dst='NAME'
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        if mi==2:
            part.vertex_groups.clear()
            headgroup=part.vertex_groups.new(name=new_by_id[5].name);neckgroup=part.vertex_groups.new(name=new_by_id[4].name)
            for vertex in part.data.vertices:
                headweight=max(0,min(1,(vertex.co.x-.565)/.10))
                if headweight>0: headgroup.add([vertex.index],headweight,'REPLACE')
                if headweight<1: neckgroup.add([vertex.index],1-headweight,'REPLACE')
            smooth=part.modifiers.new('Smooth facial surface','SMOOTH');smooth.factor=.7;smooth.iterations=8;bpy.ops.object.modifier_apply(modifier=smooth.name)
            for vertex in part.data.vertices:
                x,y,z=vertex.co
                if y>0:
                    for eye_z in [-.034,.027]:
                        d=((x-.728)/.025)**2+((z-eye_z)/.027)**2
                        if d<1: vertex.co.y=max(vertex.co.y,.086-.012*d)
            if not part.data.uv_layers: part.data.uv_layers.new(name=donor.data.uv_layers.active.name)
            part.data.uv_layers.active.name=donor.data.uv_layers.active.name
            uvmod=part.modifiers.new('Face UV transfer','DATA_TRANSFER');uvmod.object=donor;uvmod.use_loop_data=True;uvmod.data_types_loops={'UV'};uvmod.loop_mapping='POLYINTERP_NEAREST';uvmod.layers_uv_select_src='ALL';uvmod.layers_uv_select_dst='NAME'
            bpy.ops.object.modifier_apply(modifier=uvmod.name)
            uvdata=part.data.uv_layers.active.data
            for poly in part.data.polygons:
                for li in poly.loop_indices:
                    x,y,z=part.data.vertices[part.data.loops[li].vertex_index].co
                    if y>.015 and .60<x<.83:
                        mix=min(1,max(0,(y-.015)/.025))*min(1,max(0,(.081-abs(z))/.02))
                        planar=Vector((.5+z*4.7,.60+(x-.728)*3.35))
                        uvdata[li].uv=uvdata[li].uv.lerp(planar,mix)
            part.data.uv_layers.active.name='UVMap'
            part.data.materials.clear();part.data.materials.append(mat)
            for poly in part.data.polygons: poly.material_index=0
            bpy.data.objects.remove(donor,do_unlink=True);parts.append(part);part.select_set(False)
            continue
        # Bake into a fresh UV atlas instead of interpolating across the old atlas seams.
        part.data.materials.clear()
        bakedmat=bpy.data.materials.new('Polat_'+mat.name);bakedmat.use_nodes=True
        part.data.materials.append(bakedmat)
        for poly in part.data.polygons: poly.material_index=0
        bpy.ops.object.select_all(action='DESELECT');part.select_set(True);bpy.context.view_layer.objects.active=part
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
        size=1024 if mi in [0,2] else 512
        baked=bpy.data.images.new('polat_baked_'+mat.name.lower(),width=size,height=size,alpha=False)
        nodes=bakedmat.node_tree.nodes;tex=nodes.new('ShaderNodeTexImage');tex.image=baked;tex.label=baked.name;nodes.active=tex
        donor.select_set(False);source_mesh.select_set(True);part.select_set(True);bpy.context.view_layer.objects.active=part
        bpy.ops.object.bake(type='DIFFUSE')
        source_mesh.select_set(False)
        bakedmat.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
        nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85
        baked.filepath_raw=str(SRC/'textures'/f'{baked.name}.png');baked.file_format='PNG';baked.save();baked.pack()
        texture_sizes[baked.name]=[size,size]
        bpy.data.objects.remove(donor,do_unlink=True)
        mat=bakedmat
    part.data.materials.clear();part.data.materials.append(mat)
    for poly in part.data.polygons: poly.material_index=0
    if part.data.uv_layers: part.data.uv_layers.active.name='UVMap'
    if mi in [3,4]:
        # Close the open rear of the original eye surface without capping over its iris.
        shell=part.modifiers.new('Eye surface backing','SOLIDIFY');shell.solidify_mode='NON_MANIFOLD';shell.thickness=.0003;shell.offset=-1
        bpy.ops.object.modifier_apply(modifier=shell.name)
        for vertex in part.data.vertices: vertex.co.y+=.008
    parts.append(part);part.select_set(False)
source_mesh.hide_render=True;source_mesh.hide_set(True)
for part in parts: part.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='polat'
modifier=mesh.modifiers.new('Original GTA SA skeleton','ARMATURE');modifier.object=arm
bpy.data.objects.remove(source_mesh,do_unlink=True)
# Remove duplicate faces/loose points, close clothing seam boundaries.
bm=bmesh.new();bm.from_mesh(mesh.data)
before=dict(vertices=len(bm.verts),nonmanifold_edges=sum(not e.is_manifold for e in bm.edges))
# Avoid welding distinct thin shells back together.
# Split the few remaining branching edges in the supplied clothing mesh.
branching=[e for e in bm.edges if len(e.link_faces)>2]
if branching: bmesh.ops.split_edges(bm,edges=branching)
loose=[v for v in bm.verts if not v.link_faces]
if loose: bmesh.ops.delete(bm,geom=loose,context='VERTS')
boundaries=[e for e in bm.edges if e.is_boundary]
closed=bmesh.ops.holes_fill(bm,edges=boundaries,sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(mesh.data);bm.free();mesh.data.update()
# Normalize again after welding, removing even zero-weight leftover memberships.
for v in mesh.data.vertices:
    keep=sorted([(g.group,g.weight) for g in v.groups if g.weight>1e-6],key=lambda a:a[1],reverse=True)[:4]
    total=sum(w for _,w in keep);assert total>0
    for g in list(v.groups): mesh.vertex_groups[g.group].remove([v.index])
    for gi,w in keep: mesh.vertex_groups[gi].add([v.index],w/total,'REPLACE')
assert signature(arm)==original
for p in mesh.data.polygons: p.use_smooth=True
bm=bmesh.new();bm.from_mesh(mesh.data)
report=dict(source_mesh='modloader/Triboos_Test/triboss.dff (pre-existing user asset, adapted in Blender)',source_skeleton='models/gta3.img:mafboss.dff',triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons),vertices=len(mesh.data.vertices),bones=len(arm.data.bones),skeleton_unchanged=True,nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),boundary_edges=sum(e.is_boundary for e in bm.edges),wire_edges=sum(e.is_wire for e in bm.edges),loose_vertices=sum(not v.link_faces for v in bm.verts),max_influences=max(len(v.groups) for v in mesh.data.vertices),before=before,textures=texture_sizes,closed_faces=len(closed['faces']))
bm.free();(SRC/'mesh_validation.json').write_text(json.dumps(report,indent=2));print(report)
out=ROOT/'KurtlarVadisi/staging/skins';out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True);arm.select_set(True)
if arm.parent: arm.parent.select_set(True)
bpy.context.view_layer.objects.active=mesh
dff_exporter.export_dff(dict(selected=True,export_frame_names=True,exclude_geo_faces=False,mass_export=False,preserve_positions=True,preserve_rotations=True,directory=str(out),version=0x36003,export_coll=False,coll_ext_type='SA',apply_coll_trans=False,from_outliner=False,file_name=str(out/'polat.dff')))
txd_exporter.export_txd(dict(directory=str(out),file_name=str(out/'polat.txd'),version=0x36003,only_used_textures=True))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world.color=(.15,.15,.15)
coords=[v.co for v in mesh.data.vertices];target=Vector(((min(v.x for v in coords)+max(v.x for v in coords))*.5,0,0))
data=bpy.data.cameras.new('Preview');cam=bpy.data.objects.new('Preview',data);scene.collection.objects.link(cam);scene.camera=cam
cam.location=target+Vector((.08,4,.4));back=(cam.location-target).normalized();right=Vector((1,0,0)).cross(back).normalized();up=back.cross(right);cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler();data.type='ORTHO';data.ortho_scale=2.3
for name,pos,power in [('Key',(2,4,3),550),('Fill',(-1,2,-3),300)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.size=4;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard'
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'polat.blend'))
scene.render.filepath=str(SRC/'preview.png');bpy.ops.render.render(write_still=True)
cam.location.x+=.76;data.ortho_scale=.5;scene.render.filepath=str(SRC/'face_preview.png');bpy.ops.render.render(write_still=True)
