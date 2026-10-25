"""Diff against the pre-visual working tree, preserving the arsenal/Claude layers."""
from pathlib import Path
import difflib
import hashlib
import json

folder = Path(__file__).resolve().parent
root = folder.parents[2]
parts = []
paths = []
for before in sorted((folder/'baseline').rglob('*')):
    if not before.is_file(): continue
    path = 'native/godot/' + before.relative_to(folder/'baseline').as_posix()
    after = root/path
    old = before.read_text(encoding='utf-8')
    new = after.read_text(encoding='utf-8')
    if old == new: continue
    parts.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True), fromfile='a/'+path, tofile='b/'+path))
    paths.append(path)
for path in ['native/godot/tools/visual-finish-views.gd', 'native/VISUAL-FINISH-2026-10-12.md']:
    parts.extend(difflib.unified_diff([], (root/path).read_text(encoding='utf-8').splitlines(True), fromfile='/dev/null', tofile='b/'+path))
    paths.append(path)
(folder/'visual-finish.patch').write_text(''.join(parts), encoding='utf-8')
paths.append('build/regional-preview/DOMINION.exe')
(folder/'sha256.json').write_text(json.dumps({p: hashlib.sha256((root/p).read_bytes()).hexdigest() for p in paths}, indent=2), encoding='utf-8')
print('Packaged', len(paths)-1, 'source files and preview fingerprint')
