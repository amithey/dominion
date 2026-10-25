"""Package only this expansion; leave concurrent Claude AI and previous UI work out."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[3]
folder = Path(__file__).resolve().parent
tracked = ["native/godot/scripts/force_catalog.gd", "native/godot/scripts/force_models.gd", "native/godot/scripts/regional_factions.gd", "native/godot/scripts/side_panels.gd", "native/godot/tools/force-roster-check.gd"]
new = ["native/godot/scripts/arsenal_diversity_data.gd", "native/godot/scripts/arsenal_diversity_panel.gd", "native/godot/tools/arsenal-diversity-check.gd", "native/godot/tools/arsenal-diversity-views.gd", "native/ARSENAL-DIVERSITY-RESEARCH-2026-10-12.md", "native/review/codex-arsenal-handoff/build_report.py"]
patch = subprocess.check_output(["git", "diff", "--", *tracked], cwd=root).decode("utf-8")

def diff(path, before, after):
    return "".join(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile="/dev/null" if not before else "a/" + path, tofile="b/" + path))

world = "native/godot/scripts/world.gd"
after = (root / world).read_text(encoding="utf-8")
before = after
hooks = [
    ('"medic", "machineGunTeam", "mortarTeam", "scoutTeam", "recoillessTeam"]', '"medic", "machineGunTeam", "mortarTeam", "scoutTeam"]'),
    ('"reconVehicle", "directFire", "towedHowitzer", "wheeledHowitzer", "shortRangeSAM"]', '"reconVehicle", "directFire", "towedHowitzer"]'),
    ('["samLauncher", "shortRangeSAM", "aaVehicle", "submarine", "nuclearSub", "missileBoat"]', '["samLauncher", "aaVehicle", "submarine", "nuclearSub", "missileBoat"]'),
    ('{"recoillessTeam": "rocket", "wheeledHowitzer": "shell_arc", "shortRangeSAM": "sam", "mortarTeam": "mortar",', '{"mortarTeam": "mortar",'),
]
for added, original in hooks:
    assert before.count(added) == 1, added
    before = before.replace(added, original)
patch += diff(world, before, after)

runner = "native/run-tests.ps1"
after = (root / runner).read_text(encoding="utf-8")
entry = next(line for line in after.splitlines(keepends=True) if "res://tools/arsenal-diversity-check.gd" in line)
patch += diff(runner, after.replace(entry, ""), after)
for path in new:
    patch += diff(path, "", (root / path).read_text(encoding="utf-8"))
(folder / "arsenal-diversity.patch").write_text(patch, encoding="utf-8")
paths = tracked + new + [world, runner, "build/regional-preview/DOMINION.exe"]
fingerprints = {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
(folder / "sha256.json").write_text(json.dumps(fingerprints, indent=2), encoding="utf-8")
print(f"Packaged {len(paths)} fingerprints; world.gd limited to four arsenal hooks, runner to one entry")
