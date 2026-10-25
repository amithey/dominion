from pathlib import Path
import difflib, hashlib, json
folder = Path(__file__).resolve().parent
root = folder.parents[2]
patch, paths = [], []
def add(path, old, new):
    if old == new: return
    patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='a/'+path if old else '/dev/null', tofile='b/'+path))
    paths.append(path)
for name in ['world.gd','hud.gd','airlift.gd','un_session_screen.gd']:
    path = 'native/godot/scripts/' + name
    add(path, (folder/'baseline'/name).read_text(encoding='utf-8'), (root/path).read_text(encoding='utf-8'))
path = 'native/run-tests.ps1'
project = 'native/godot/project.godot'
add(project, (folder/'baseline/project.godot').read_text(encoding='utf-8'), (root/project).read_text(encoding='utf-8'))
new = (root/path).read_text(encoding='utf-8')
old = ''.join(line for line in new.splitlines(True) if not any(k in line for k in ['res://tools/customer-airlift-check.gd','res://tools/customer-window-check.gd']))
add(path,old,new)
for name in ['customer-airlift-check.gd','customer-window-check.gd']:
    path = 'native/godot/tools/'+name
    add(path,'',(root/path).read_text(encoding='utf-8'))
    if (root/(path+'.uid')).exists(): add(path+'.uid','',(root/(path+'.uid')).read_text(encoding='utf-8'))
(folder/'customer-playtest.patch').write_text(''.join(patch),encoding='utf-8')
paths.append('build/regional-preview/DOMINION.exe')
(folder/'sha256.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths},indent=2),encoding='utf-8')
print('Packaged',len(paths)-1,'source files and preview fingerprint')
