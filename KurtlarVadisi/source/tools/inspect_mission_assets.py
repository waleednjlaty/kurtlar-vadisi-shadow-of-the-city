import bpy, pathlib,sys,importlib.util,json
SRC=pathlib.Path(__file__).resolve().parents[1];ROOT=SRC.parents[1]
spec=importlib.util.spec_from_file_location('dragonff',SRC/'tools/DragonFF-master/__init__.py',submodule_search_locations=[str(SRC/'tools/DragonFF-master')]);m=importlib.util.module_from_spec(spec);sys.modules['dragonff']=m;spec.loader.exec_module(m)
from dragonff.gtaLib import dff,txd
report={}
for label,part,name in [('Memati','characters/Memati','triada'),('Abdulhey','characters/Abdulhey','vmaff1'),('BMW_X5','vehicles/BMW_X5','stretch')]:
    folder=ROOT/'modloader/KurtlarVadisi'/part
    model=dff.dff();model.load_file(str(folder/(name+'.dff')));textures=txd.txd();textures.load_file(str(folder/(name+'.txd')))
    native={t.name.lower():[t.width,t.height] for t in textures.native_textures}
    clump=model.clumps[0]
    used={t.name.lower() for g in clump.geometry_list for mat in g.materials for t in mat.textures}
    report[label]={'textures':native,'required':sorted(used),'missing':sorted(used-set(native)),'frames':[f.name for f in clump.frame_list],'geometries':len(clump.geometry_list)}
(SRC/'mission001/asset_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
