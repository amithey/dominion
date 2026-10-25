from pathlib import Path
import difflib, hashlib, json
folder = Path(__file__).resolve().parent
root = folder.parents[2]
patch, paths = [], []
for path in ['native/godot/scripts/architecture.gd','native/godot/scripts/districts.gd','native/godot/scripts/world.gd',
             'native/godot/shaders/vehicle.gdshader','native/godot/shaders/terrain.gdshader','native/godot/shaders/water.gdshader',
             'native/godot/tools/scene-detail-views.gd','native/godot/tools/scene-detail-views.gd.uid']:
    if not (root/path).exists(): continue
    baseline = folder/'baseline'/Path(path).name
    old = baseline.read_text(encoding='utf-8') if baseline.exists() else ''
    new = (root/path).read_text(encoding='utf-8')
    if old == new: continue
    patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+path if old else '/dev/null',tofile='b/'+path))
    paths.append(path)
(folder/'scene-detail.patch').write_text(''.join(patch),encoding='utf-8')
paths.append('build/regional-preview/DOMINION.exe')
(folder/'sha256.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},indent=2),encoding='utf-8')
print('Packaged',len(paths)-1,'source files plus preview hash')
