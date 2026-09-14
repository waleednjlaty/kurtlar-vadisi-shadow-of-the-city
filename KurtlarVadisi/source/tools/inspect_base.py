import bpy, sys, pathlib, struct, importlib.util, json
ROOT = pathlib.Path(__file__).resolve().parents[3]
SRC = ROOT/'KurtlarVadisi/source'
addon = SRC/'tools/DragonFF-master'
spec = importlib.util.spec_from_file_location('dragonff', addon/'__init__.py', submodule_search_locations=[str(addon)])
dragonff = importlib.util.module_from_spec(spec)
sys.modules['dragonff'] = dragonff
spec.loader.exec_module(dragonff)
dragonff.register()
from dragonff.ops import dff_importer, txd_importer
ref = SRC/'references/original'
ref.mkdir(parents=True, exist_ok=True)
with (ROOT/'models/gta3.img').open('rb') as f:
    magic, count = struct.unpack('<4sI', f.read(8))
    assert magic == b'VER2'
    entries = [struct.unpack('<IHH24s', f.read(32)) for _ in range(count)]
    for offset, streaming, archive, raw in entries:
        name = raw.split(b'\0')[0].decode('ascii')
        if name.lower() in ['mafboss.dff','mafboss.txd','triboss.dff','triboss.txd']:
            f.seek(offset*2048)
            (ref/name).write_bytes(f.read((archive or streaming)*2048))
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
images = txd_importer.import_txd(dict(file_name=str(ref/'mafboss.txd'),skip_mipmaps=True,pack=True)).images
dff_importer.import_dff(dict(file_name=str(ref/'mafboss.dff'),txd_images=images,image_ext='PNG',connect_bones=False,use_mat_split=False,remove_doubles=True,create_backfaces=False,group_materials=True,import_normals=True,materials_naming='TEX',import_breakable=False))
report = []
for o in bpy.context.scene.objects:
    item = dict(name=o.name,type=o.type)
    if o.type=='MESH':
        item.update(vertices=len(o.data.vertices),triangles=sum(len(p.vertices)-2 for p in o.data.polygons),bounds=[list(v) for v in o.bound_box],materials=[m.name for m in o.data.materials])
    if o.type=='ARMATURE':
        item['bones']=[dict(name=b.name,parent=b.parent.name if b.parent else None,head=list(b.head_local),properties=dict(b.items())) for b in o.data.bones]
    report.append(item)
(SRC/'base_inspection.json').write_text(json.dumps(report,indent=2))
for name, imgs in images.items():
    im=imgs[0]; im.filepath_raw=str(SRC/'textures'/f'original_{name}.png'); im.file_format='PNG'; im.save()
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'original_reference.blend'))
print(json.dumps(report,indent=2))
