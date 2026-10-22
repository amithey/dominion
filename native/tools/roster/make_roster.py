"""Builds native/CODEX-UNIT-ROSTER.md and .json from native/godot/build/unit-roster.json (godot/tools/dump-unit-roster.gd)."""
import json, os, re
from collections import Counter

here = os.path.dirname(os.path.abspath(__file__))
native = os.path.dirname(os.path.dirname(here))
d = json.load(open(os.path.join(native, 'godot', 'build', 'unit-roster.json'), encoding='utf-8'))
U = d['units']
have = set()
for sub in ('vehicles', 'aircraft', 'ships'):
    p = os.path.join(native, 'godot', 'assets', 'art', sub)
    if os.path.isdir(p):
        have |= {os.path.basename(f)[:-4] for f in os.listdir(p) if f.endswith('.glb')}

groups = [
    ("P1 Main battle tanks", ["tank"], "Tracked, turreted. Nodes as Tier 7: Hull, Turret, Gun, Muzzle, Wheel_L0.., Wheel_R0.., Sprocket_*, Idler_*, Roller_*, Track_L/R, Wreck."),
    ("P2 Armoured personnel carriers, infantry fighting vehicles and other armour", ["apc", "ifv", "heavyAPC", "bushmaster", "reconVehicle", "recoveryVehicle", "mineClearer", "mineLayer", "ewVehicle"], "Tracked or wheeled. Turret and Gun only where the real vehicle has them; a recovery vehicle names its boom Boom and its spade Spade."),
    ("P3 Artillery and rocket launchers", ["artillery", "towedHowitzer", "wheeledHowitzer", "k9", "mlrs", "himars", "heavyRocket", "tos1a", "directFire", "coastalASM", "brahmos", "df17", "shahedLauncher"], "Self-propelled: Hull, Turret, Gun (elevates) with Muzzle. Rocket launchers: Hull, Launcher (pod or rack: axis X to elevate, axis Y turntable if it traverses), Muzzle marker at the front of the pod. Towed guns: Carriage, Gun (elevates), Trail_L/R (the legs), Wheel_L0/R0."),
    ("P4 Air defence and radars", ["aaVehicle", "samLauncher", "abmLauncher", "saudiThaad", "irisT", "laserAD", "shortRangeSAM", "hpmVehicle", "counterBatteryRadar"], "Hull or truck, Launcher (elevates about X, turntable about Y), Radar (spins about Y), Muzzle markers at each missile tube or barrel (Muzzle_0, Muzzle_1, ...)."),
    ("P5 Helicopters", ["helicopter", "gunship", "navalHelicopter", "heavyLift", "scoutHelicopter"], "Fuselage, Rotor_Main (axis Y, hub pivot), Rotor_Tail (axis X), Skid or Gear, Muzzle markers for the gun and the stub wings."),
    ("P6 Aircraft (fixed wing and drones)", ["jet", "lightFighter", "stealthFighter", "attackJet", "raptor", "jf17", "superTucano", "carrierJet", "ewJet", "bomber", "aewc", "maritimePatrol", "drone", "akinci", "heavyBomberDrone", "carrierDrone", "interceptorDrone", "shahed", "loiterer", "harop"], "Fuselage, Gear_Nose, Gear_Left, Gear_Right (retract about their hinge), Flap_L/R, Aileron_L/R, Rudder, Canopy, Afterburner (marker), Propeller (axis Z, only where it has one), Rotodome (spins about Y, only for AEW)."),
    ("P7 Ships and submarines", ["destroyer", "aegisCruiser", "type45", "corvette", "asFrigate", "kcr60", "missileBoat", "gunboat", "landingShip", "carrier", "submarine", "nuclearSub", "seaDrone"], "Hull, Turret_Main (axis Y) with Gun, Radar (axis Y), Wake_Bow and Wake_Stern markers, Propeller (submarines). The carrier: a flat deck with an island and Catapult_0.. markers; a landing ship: Ramp (pivot at the hinge)."),
]


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')[:48].rstrip('_')


def done(sl):
    # the game falls back from "leclerc_xlr" to "leclerc"
    base = sl
    while True:
        if base in have:
            return True
        tail = base.split('__', 1)[1]
        if '_' not in tail:
            return False
        base = base.rsplit('_', 1)[0]


md = ["# Unit roster for Codex: every vehicle, aircraft and ship, as each nation fields it\n\n",
      "Generated from the game's own data (%d nations) by native/tools/roster/make_roster.py. Read `native/CODEX-ART-REQUEST.md` (Tier 7) first for the file conventions; this file says **which models**.\n\n" % len(d['nations']),
      "**One model per row.** The model name is the designation the nation fields; build that real vehicle's general look, generic and without national marks. Where several nations share a name, build it once. Where you do not know the real vehicle, build a plausible generic one of its class and mark `\"approximate\": true` in the manifest.\n\n",
      "**File name:** `native/godot/assets/art/<vehicles|aircraft|ships>/<key>__<slug>.glb`. The game finds a model by the nation's own name for the unit, and a variant name finds its base vehicle's file (\"Leclerc XLR\" finds `leclerc`), so a variant needs a file of its own only if it looks different.\n\n",
      "The last column says whether the file already exists.\n"]
rows = []
todo = 0
for title, keys, notes in groups:
    md.append("\n## %s\n\n%s\n" % (title, notes))
    for k in keys:
        if k not in U:
            continue
        u = U[k]
        by = {}
        for nid, nm in u['nations'].items():
            by.setdefault(nm, []).append(nid)
        md.append("\n### `%s` (%s): %d model(s)\n\n| # | Model name (as the nation calls it) | Nations | File slug | |\n|---|---|---|---|---|\n" % (k, u['generic'], len(by)))
        for i, (nm, nats) in enumerate(sorted(by.items(), key=lambda x: x[0].lower()), 1):
            sl = "%s__%s" % (k, slug(nm))
            ok = done(sl)
            md.append("| %d | %s | %s | `%s` | %s |\n" % (i, nm, ', '.join(sorted(nats)), sl, 'done' if ok else 'TO DO'))
            rows.append({"priority": title.split()[0], "key": k, "model": nm, "slug": sl, "nations": sorted(nats), "done": ok})
            todo += 0 if ok else 1
md.append("\nTotal: %d models, %d still to do.\n" % (len(rows), todo))
open(os.path.join(native, 'CODEX-UNIT-ROSTER.md'), 'w', encoding='utf-8', newline='\n').write(''.join(md))
open(os.path.join(native, 'CODEX-UNIT-ROSTER.json'), 'w', encoding='utf-8', newline='\n').write(json.dumps(rows, indent=1, ensure_ascii=False))
print(len(rows), todo, sorted(Counter((r['priority'], r['done']) for r in rows).items()))
