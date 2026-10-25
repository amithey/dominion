from pathlib import Path
import difflib, hashlib, json
folder = Path(__file__).resolve().parent
root = folder.parents[2]
patch, paths = [], []

def add(path, old, new):
    if old == new: return
    patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
        fromfile='a/'+path if old else '/dev/null', tofile='b/'+path))
    paths.append(path)

for name in ['hud.gd', 'side_panels.gd', 'menu.gd', 'ui_theme.gd']:
    path = 'native/godot/scripts/' + name
    add(path, (folder/'baseline'/name).read_text(encoding='utf-8'), (root/path).read_text(encoding='utf-8'))
path = 'native/godot/tools/readability-check.gd'
add(path, (folder/'baseline/readability-check.gd').read_text(encoding='utf-8'), (root/path).read_text(encoding='utf-8'))
path = 'native/run-tests.ps1'
new = (root/path).read_text(encoding='utf-8')
entry = next(line for line in new.splitlines(True) if 'res://tools/action-copy-check.gd' in line)
add(path, new.replace(entry,''), new)
new_files = ['native/godot/scripts/action_copy.gd', 'native/godot/scripts/button_hints.gd',
             'native/godot/scripts/weapon_copy.gd', 'native/godot/tools/action-copy-check.gd']
for path in new_files:
    add(path, '', (root/path).read_text(encoding='utf-8'))
    if (root/(path+'.uid')).exists(): add(path+'.uid', '', (root/(path+'.uid')).read_text(encoding='utf-8'))
(folder/'action-copy.patch').write_text(''.join(patch), encoding='utf-8')
paths.append('build/regional-preview/DOMINION.exe')
(folder/'sha256.json').write_text(json.dumps({p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}, indent=2),encoding='utf-8')
print('Packaged', len(paths)-1, 'source files and preview fingerprint')
