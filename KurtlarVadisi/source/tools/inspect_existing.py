exec(compile((__import__('pathlib').Path(__file__).parent/'inspect_base.py').read_text(),str(__import__('pathlib').Path(__file__).parent/'inspect_base.py'),'exec'))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
folder=ROOT/'modloader/Triboos_Test'
images=txd_importer.import_txd(dict(file_name=str(folder/'triboss.txd'),skip_mipmaps=True,pack=True)).images
for name,imgs in images.items():
    im=imgs[0]; im.filepath_raw=str(SRC/'textures'/f'existing_{name}.png'); im.file_format='PNG'; im.save()
dff_importer.import_dff(dict(file_name=str(folder/'triboss.dff'),txd_images=images,image_ext='PNG',connect_bones=False,use_mat_split=True,remove_doubles=True,create_backfaces=False,group_materials=True,import_normals=True,materials_naming='TEX'))
for o in bpy.context.scene.objects:
    print('EXISTING',o.name,o.type, len(o.data.vertices) if o.type=='MESH' else '')
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'existing_mod_reference.blend'))
