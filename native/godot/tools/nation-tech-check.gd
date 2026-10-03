extends SceneTree
## Every nation fields its own technology, as in 2025-26 (national_variants.gd):
## playing each of the nine, the units and research it may have carry no
## other bloc's systems in their names or descriptions (no F-35 for China, no
## Western weapons for Iran, no Russian or Chinese ones for the United States);
## the weapons it lacks stay shut (heavy bombers, stealth and sixth-generation
## fighters, nuclear weapons and submarines, missile defence, lasers,
## hypersonic missiles); its starting army holds only what it fields; and its
## rivals build and fire only their own.
var errors: Array[String] = []
var passed := 0
var w: Node
const Factions := preload("res://scripts/factions.gd")
const V := preload("res://scripts/national_variants.gd")
const WEST := ["F-35", "F-22", "F-47", "F-15", "F-16", "Abrams", "Apache", "Javelin", "Stinger", "HIMARS", "Patriot", "THAAD", "Reaper",
	"Black Hawk", "Arleigh", "Virginia", "Ohio", "B-52", "B-21", "Raptor", "Raider", "Switchblade", "Leonidas", "Paladin", "Stryker", "M270",
	"Leopard", "Rafale", "Typhoon", "Mistral", "Boxer", "PzH", "Tiger", "NH90", "SAMP/T", "IRIS-T", "Golden Dome", "Orca", "SM-3", "Aegis"]
const ISRAELI := ["Iron Beam", "Iron Dome", "Arrow", "Spike", "Hermes", "Heron", "Harop", "Hero-", "Merkava", "Trophy", "David's Sling", "Eitan", "PULS", "Sa'ar", "Dolphin"]
const EASTERN := ["Su-3", "Su-5", "MiG", "T-90", "Kornet", "S-400", "S-500", "Lancet", "Pantsir", "J-20", "J-36", "J-16", "Type 055", "DF-", "HQ-",
	"Wing Loong", "Tu-160", "H-6K", "Shahed Launcher", "TOS-1", "Krasukha", "Borei", "Karakurt", "Z-10", "Z-20", "Kilo"]
## Names a nation must not see on its own weapons.
const BANNED := {
	"usa": ["EASTERN"], "eu": ["EASTERN"], "japan": ["EASTERN"], "israel": ["EASTERN"],
	"china": ["WEST", "ISRAELI"], "iran": ["WEST", "ISRAELI"], "russia": ["WEST", "ISRAELI"],
	"india": ["ISRAELI_NONE"], "turkiye": ["ISRAELI_NONE"],
}
## What each nation lacks.
const LACKS := {
	"usa": ["railgunShip"], "china": ["raptor", "raider"],
	"eu": ["bomber", "sixthGen", "hpmVehicle", "railgunShip", "orca"],
	"iran": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "laserAD", "abmLauncher", "hpmVehicle", "railgunShip", "orca", "raptor", "irisT"],
	"russia": ["sixthGen", "hpmVehicle", "railgunShip", "orca"],
	"india": ["bomber", "sixthGen", "hpmVehicle", "railgunShip", "orca"],
	"japan": ["bomber", "sixthGen", "nuclearSub", "orca"],
	"turkiye": ["bomber", "sixthGen", "nuclearSub", "hpmVehicle", "railgunShip", "orca"],
	"israel": ["bomber", "sixthGen", "nuclearSub", "destroyer", "hpmVehicle", "railgunShip", "orca"],
	"uk": ["bomber", "sixthGen", "railgunShip", "orca", "raptor"],
	"south_korea": ["bomber", "sixthGen", "nuclearSub", "railgunShip", "orca"],
	"saudi": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "submarine", "railgunShip"],
	"brazil": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "abmLauncher"],
	"indonesia": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "abmLauncher"],
	"ukraine": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "submarine", "abmLauncher"],
	"north_korea": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "abmLauncher"],
	"egypt": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "abmLauncher"],
	"australia": ["bomber", "sixthGen", "nuclearSub", "railgunShip", "orca"],
	"pakistan": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "abmLauncher"],
	"iraq": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "submarine", "himars", "abmLauncher", "railgunShip", "orca"],
	"syria": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "submarine", "jet", "gunship", "corvette", "samLauncher", "himars", "abmLauncher"],
	"afghanistan": ["bomber", "stealthFighter", "sixthGen", "nuclearSub", "submarine", "destroyer", "corvette", "gunboat", "jet", "gunship", "samLauncher", "himars", "seaDrone", "abmLauncher"],
}
const EXPECT_NAMES := {"china": {"stealthFighter": "J-20", "sixthGen": "J-36", "tank": "Type 99A"}, "russia": {"stealthFighter": "Su-57", "tank": "T-90M Proryv"},
	"usa": {"stealthFighter": "F-35A Lightning II", "sixthGen": "F-47"}, "iran": {"jet": "MiG-29", "tank": "Karrar"}, "israel": {"stealthFighter": "F-35I Adir", "laserAD": "Iron Beam"},
	"turkiye": {"stealthFighter": "KAAN", "drone": "Bayraktar TB2"}, "japan": {"stealthFighter": "F-35A", "tank": "Type 10"}, "india": {"stealthFighter": "AMCA", "jet": "Su-30MKI"}, "eu": {"tank": "Leopard 2A8"},
	"iraq": {"jet": "F-16IQ Fighting Falcon", "tank": "M1A1M Abrams"}, "syria": {"tank": "T-72"}, "afghanistan": {"helicopter": "UH-60 (captured)"}}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func words(list_name: String) -> Array:
	match list_name:
		"WEST": return WEST
		"ISRAELI": return ISRAELI
		"EASTERN": return EASTERN
	return []

func run() -> void:
	for index in range(Factions.IDS.size()):
		var id: String = Factions.IDS[index]
		set_meta("match_config", {"map": "island", "players": 4, "nation": index, "style": "standard"})
		change_scene_to_file("res://world.tscn")
		w = null
		for i in range(8000):
			await process_frame
			if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
				w = current_scene
				break
		if w.menu.get("_root") == null: w.menu.setup(w)
		seed(hash(id))
		w.start_match("hard")
		w.menu._root.hide()
		for i in range(5): await physics_frame
		w.set_physics_process(false)
		w.ai.set_physics_process(false)
		print("== %s" % id)
		# 1: its own units carry no other bloc's names.
		var banned: Array = []
		for group in BANNED.get(id, []): banned += words(group)
		var clashes := []
		for key in w.unit_defs:
			if not w.unit_allowed(0, key): continue
			var text: String = "%s %s" % [w.unit_defs[key].get("name", ""), w.unit_defs[key].get("desc", "")]
			for word in banned:
				if word in text: clashes.append("%s: %s" % [key, word])
		for key in w.research.discoveries:
			if w.research.blocker(key).ends_with("only") or w.research.blocker(key).begins_with("Not fielded"): continue
			var d: Dictionary = w.research.discoveries[key]
			var text: String = "%s %s" % [d.get("name", ""), d.get("desc", "")]
			for word in banned:
				if word in text: clashes.append("research %s: %s" % [key, word])
		check(clashes.is_empty(), "%s: no other bloc's weapons among its own%s" % [id, "" if clashes.is_empty() else " " + str(clashes)])
		# 2: what it lacks stays shut, to it and to its rivals of the same flag.
		var open := []
		for key in LACKS[id]:
			if w.unit_defs.has(key) and w.unit_allowed(0, key): open.append(key)
			if w.unit_defs.has(key) and w.research.unit_locked(key) == "": open.append(key + " (unlocked)")
		check(open.is_empty(), "%s: the weapons it lacks stay shut%s" % [id, "" if open.is_empty() else " " + str(open)])
		# 3: its own names.
		var wrong := []
		for key in EXPECT_NAMES.get(id, {}):
			if str(w.unit_defs[key].name) != EXPECT_NAMES[id][key]: wrong.append("%s is %s" % [key, w.unit_defs[key].name])
		check(wrong.is_empty(), "%s: its systems by their own names %s" % [id, str(EXPECT_NAMES.get(id, {}).values()) if wrong.is_empty() else str(wrong)])
		# 4: nuclear weapons and hypersonic missiles.
		var nuclear: bool = id in ["usa", "china", "eu", "russia", "india", "israel", "uk", "north_korea", "pakistan"]
		var hyper: bool = id in ["usa", "china", "russia", "india", "iran", "japan", "turkiye"]
		var nuke_open: bool = not w.missiles.locked("nuke").ends_with("only") and not w.missiles.locked("nuke").begins_with("Not fielded")
		var hyper_open: bool = not w.missiles.locked("hypersonic").begins_with("Not fielded")
		var program_open: bool = not w.research.blocker("nuclearProgram").begins_with("Not fielded")
		check(nuke_open == nuclear and program_open == nuclear, "%s: nuclear weapons %s" % [id, "open (a nuclear power)" if nuclear else "shut"])
		check(hyper_open == hyper, "%s: hypersonic missiles %s" % [id, "open" if hyper else "shut"])
		# 5: its starting army.
		var foreign: Array = w.units.filter(func(u): return u.owner == 0 and not w.unit_allowed(0, u.key)).map(func(u): return u.key)
		check(foreign.is_empty(), "%s: its starting army holds only what it fields%s" % [id, "" if foreign.is_empty() else " " + str(foreign)])
		# 6: rivals build and fire only their own.
		for n in w.ai.nations:
			n.money = 60000.0
			n.tech = 9.0
		for i in range(900): w.ai._physics_process(0.2)
		w.economy.tick()
		var rogue: Array = w.units.filter(func(u): return u.owner > 0 and not u.dead and not w.unit_allowed(u.owner, u.key)).map(func(u): return "%d:%s" % [u.owner, u.key])
		var trained: int = w.units.filter(func(u): return u.owner > 0 and not u.dead).size()
		check(rogue.is_empty() and trained > 12, "%s match: rivals field only their own weapons (%d units%s)" % [id, trained, "" if rogue.is_empty() else ", " + str(rogue)])
		var bad_shots := []
		for n in w.ai.nations:
			w.diplomacy.declare_war(n.id, 0)
			var rid: String = preload("res://scripts/national_arsenal.gd").identity(w, n.id)
			for i in range(12):
				n.money = 5000.0
				var m: Dictionary = w.ai.missile_strike(n, w.ai.hq(n.id), 8.0)
				if not m.is_empty() and not V.admits(w.missiles.def_of(m.type).get("nation", ""), rid): bad_shots.append("%s:%s" % [rid, m.type])
		check(bad_shots.is_empty(), "%s match: rivals fire only missiles they have%s" % [id, "" if bad_shots.is_empty() else " " + str(bad_shots)])
	print("\nNATION_TECH: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("NATION_TECH PASS" if errors.is_empty() else "NATION_TECH FAIL")
	quit(0 if errors.is_empty() else 1)
