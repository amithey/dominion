extends SceneTree
## The testing cheat (cheats.gd): F10, or "Testing: everything" in the pause
## menu. Every era, every discovery your nation fields, every track maxed,
## the money, the stores and homes filled; another nation's own technology
## stays theirs; every unit and missile of your own unlocked; what is trained
## next has the bonuses; a save keeps it; pressed again, nothing breaks.
var errors: Array[String] = []
var passed := 0
var w: Node
const Arsenal := preload("res://scripts/national_arsenal.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func begin(cfg: Dictionary) -> void:
	set_meta("match_config", cfg)
	change_scene_to_file("res://world.tscn")
	w = null
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("menu") != null and current_scene.get("nav_ready") == true:
			w = current_scene
			break
	if w.menu.get("_root") == null: w.menu.setup(w)
	w.start_match("easy")
	w.menu._root.hide()
	for i in range(5): await physics_frame

func f10() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = true
	w._input(key)

func run() -> void:
	# USA: F10.
	await begin({"map": "crown", "players": 4, "nation": 0})
	var r: Node = w.research
	var eco: Node = w.economy
	var money0: float = eco.res.money
	var pop0: int = eco.pop_cap
	var done0: int = r.completed_count()
	f10()
	await process_frame
	var own: Array = r.discoveries.keys().filter(func(k): return Arsenal.foreign(w, r.def_of(k).get("nation", "")) == "")
	var theirs: Array = r.discoveries.keys().filter(func(k): return Arsenal.foreign(w, r.def_of(k).get("nation", "")) != "")
	print("USA: %d discoveries of its own, %d of other nations; %d done before" % [own.size(), theirs.size(), done0])
	check(r.era == r.eras.size() - 1, "F10: the last era reached (%s)" % r.eras[r.era].name)
	check(own.all(func(k): return r.done(k)) and own.size() > done0, "F10: all %d of your nation's discoveries complete" % own.size())
	check(theirs.size() > 0 and theirs.all(func(k): return not r.done(k)), "F10: the %d discoveries only other nations field stay theirs" % theirs.size())
	check(r.tracks.keys().all(func(k): return r.tracks[k] == int(r.tracks_cfg[k].max)) and r.queue.is_empty(), "F10: every research track at its last level, nothing left in the queue")
	check(eco.res.money >= money0 + 1000000.0, "F10: $1,000,000 more ($%d)" % int(eco.res.money))
	var short: Array = eco.caps.keys().filter(func(k): return eco.res.get(k, 0.0) < eco.caps[k] or eco.caps[k] < 99999.0)
	check(short.is_empty(), "F10: every store full, limits 99,999%s" % ("" if short.is_empty() else " (not %s)" % str(short)))
	check(eco.civilians >= eco.civ_cap and eco.pop_cap >= pop0 + 200, "F10: homes filled (%d), army capacity +200 (%d)" % [int(eco.civilians), eco.pop_cap])
	var units: Array = w.unit_defs.keys().filter(func(k): return Arsenal.foreign(w, w.unit_defs[k].get("nation", "")) == "")
	var still: Array = units.filter(func(k): return r.unit_locked(k) != "")
	check(still.is_empty(), "F10: every unit your nation fields unlocked (%d)%s" % [units.size(), "" if still.is_empty() else ": not " + str(still)])
	var missiles: Array = w.missiles.types().keys().filter(func(k): return Arsenal.foreign(w, w.missiles.def_of(k).get("nation", "")) == "" and not w.missiles.def_of(k).get("hidden", false))   # (a MIRV's warheads ride its missile)
	var shut: Array = missiles.filter(func(k): return w.missiles.locked(k) != "")
	check(shut.is_empty(), "F10: every missile your nation fields unlocked (%d)%s" % [missiles.size(), "" if shut.is_empty() else ": not " + str(shut)])
	var tank: Dictionary = w.spawn_unit("tank", w.land_point(w.start, 30.0), 0)
	check(tank.max_hp > float(w.unit_defs.tank.hp) * 1.05, "F10: a tank trained now has the research's armour (%d hp, %d base)" % [int(tank.max_hp), int(w.unit_defs.tank.hp)])
	var told: Array = w.hud.find_children("*", "Label", true, false).filter(func(l): return l.text.begins_with("Testing: every era"))
	check(not told.is_empty(), "F10: a notice says what was given (%s)" % (told[0].text.substr(0, 60) + "..." if not told.is_empty() else "none"))
	# Pressed again: nothing breaks, the money grows, nothing more to open.
	var money1: float = eco.res.money
	f10()
	await process_frame
	check(eco.res.money >= money1 + 1000000.0 and r.completed_count() == own.size() and not is_nan(eco.res.money), "F10 twice: more money, the research as it was")
	# Kept in a save.
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	w.saves.restore(data)
	for i in range(5): await process_frame
	check(w.research.era == w.research.eras.size() - 1 and w.research.completed_count() == own.size() and w.economy.res.money >= money1 + 1000000.0 - 1.0, "a save keeps the era, the research and the money")
	# Iran from the pause menu: its own technology only (no F-35, no Iron Dome).
	await begin({"map": "crown", "players": 4, "nation": 3})
	w.menu.open_pause()
	await process_frame
	var button: Button = w.menu._root.find_child("CheatEverything", true, false)
	check(button != null, "the pause menu has the Testing: everything button")
	if button != null:
		button.pressed.emit()
		await process_frame
	r = w.research
	var mine: Array = r.discoveries.keys().filter(func(k): return Arsenal.foreign(w, r.def_of(k).get("nation", "")) == "")
	var foreign_units: Array = w.unit_defs.keys().filter(func(k): return Arsenal.foreign(w, w.unit_defs[k].get("nation", "")) != "" and r.unit_locked(k) == "")
	check(mine.all(func(k): return r.done(k)) and r.era == r.eras.size() - 1 and w.economy.res.money >= 1000000.0, "the button: Iran gets every era and all %d of its discoveries" % mine.size())
	check(foreign_units.is_empty() and r.unit_locked("stealthFighter") != "", "the button: Iran still fields no other nation's arms (a stealth fighter: %s)" % r.unit_locked("stealthFighter"))
	check(not w.menu._root.visible or w.get_tree().paused == false, "the button closes the pause menu, back to the game")
	print("\nCHEAT: %d passed, %d failed" % [passed, errors.size()])
	for f in errors: print("  FAILED: " + f)
	print("CHEAT PASS" if errors.is_empty() else "CHEAT FAIL")
	quit(0 if errors.is_empty() else 1)
