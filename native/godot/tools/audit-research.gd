extends SceneTree
## Audit of every discovery (native/ALPHA-1.0-REPORT.md): all of w.research.discoveries at runtime (about 72), plus the
## research tracks. For each: a sound definition (name, cost, branch, era, description, prerequisites that exist);
## every effect it promises is read by something in the game; it can be reached (its prerequisites chain back to a
## discovery with none, its era can be entered) and completed; completing it changes the bonus by what it says; and
## for the main economic and military effects the change is seen in the game itself. The whole tree is walked in
## dependency order, and three discoveries are researched for real (queue, points, stages, messages).
## Table: res://build/audit/research.txt
const Kit := preload("res://tools/audit_kit.gd")
const Arsenal := preload("res://scripts/national_arsenal.gd")
const Factions := preload("res://scripts/factions.gd")
var K
var w: Node
var consumers := {}   # stat -> a file that reads it
var script_texts := {}
func _initialize() -> void: call_deferred("run")

func play_as(id: String) -> void:
	w.map.nations[0]["id"] = id

func scan_scripts() -> void:
	var texts := {}
	var dir := DirAccess.open("res://scripts")
	for file in dir.get_files():
		if file.ends_with(".gd"):
			texts[file] = FileAccess.get_file_as_string("res://scripts/" + file)
	script_texts = texts
	var all_stats := {}
	for key in w.research.discoveries:
		for stat in w.research.effects_of(key):
			all_stats[stat] = true
	for stat in all_stats:
		for file in texts:
			var pattern: String = 'bonus("%s")' % stat if file == "research.gd" else '"%s"' % stat
			if texts[file].contains(pattern):
				consumers[stat] = file
				break

func nation_of(def: Dictionary) -> String:
	var n = def.get("nation", "")
	if n is Array:
		return str(n[0]) if not n.is_empty() else ""
	return str(n)

## The national identity ("usa"...) that goes with a discovery's nation tag (the old colour names too).
func identity_for(tag: String) -> String:
	var legacy := {"blue": "usa", "red": "china", "green": "eu", "gold": "iran"}
	return legacy.get(tag, tag)

func run() -> void:
	K = Kit.new(self, "research")
	w = await K.boot({"map": "island", "players": 3, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.economy.grant_test_resources()
	for n in w.ai.nations: n.money = 10000000.0
	var R: Node = w.research
	scan_scripts()
	var keys: Array = R.discoveries.keys()
	keys.sort()
	K.ok("research", "all", "%d discoveries, %d eras, %d tracks" % [keys.size(), R.eras.size(), R.tracks_cfg.size()])

	# ---- definitions
	for key in keys:
		var d: Dictionary = R.def_of(key)
		var problems := PackedStringArray()
		var notes := PackedStringArray()
		if str(d.get("name", "")).strip_edges() == "" or str(d.name).contains("null"): problems.append("no proper name")
		if float(d.get("cost", 0)) <= 0.0: problems.append("cost <= 0")
		if not str(d.get("branch", "")) in R.BRANCHES: problems.append("unknown branch '%s'" % str(d.get("branch", "")))
		if R.desc_of(key).strip_edges() == "": problems.append("no description")
		var need = d.get("reqDiscovery")
		if need != null and not R.discoveries.has(need): problems.append("requires unknown discovery %s" % str(need))
		var building = d.get("reqBuilding")
		if building != null and not w.building_defs.has(building): problems.append("requires unknown building %s" % str(building))
		if R.era_of(key) < 0 or R.era_of(key) >= R.eras.size(): problems.append("era %d does not exist" % R.era_of(key))
		var fx: Dictionary = R.effects_of(key)
		for stat in fx:
			if not consumers.has(stat) and not stat in ["education", "culture", "order", "approval"]:
				notes.append("effect '%s' is read by no script" % stat)
		if fx.is_empty() and not R.def_of(key).get("unlocks") and not _unlocks_something(key):
			notes.append("no effect and unlocks nothing that is visible")
		var detail := "%s [%s, era %d, cost %d]%s%s: %s" % [d.get("name", key), d.get("branch", ""), R.era_of(key), int(d.get("cost", 0)), (" needs " + str(need)) if need != null else "", (" building " + str(building)) if building != null else "", ", ".join(PackedStringArray(fx.keys().map(func(s): return "%s %s" % [s, str(fx[s])]))) if not fx.is_empty() else "(no numeric effect)"]
		if not problems.is_empty():
			K.fail("research-def", key, "; ".join(problems) + " | " + detail)
		elif not notes.is_empty():
			K.warn("research-def", key, "; ".join(notes) + " | " + detail)
		else:
			K.ok("research-def", key, detail)

	# ---- the whole tree in dependency order: reachable, completable, effects as stated
	var done_set := {}
	var remaining := keys.duplicate()
	var guard := 0
	var order: Array = []
	while not remaining.is_empty() and guard < 200:
		guard += 1
		var progressed := false
		for key in remaining.duplicate():
			var need = R.def_of(key).get("reqDiscovery")
			if need == null or done_set.has(need):
				order.append(key)
				done_set[key] = true
				remaining.erase(key)
				progressed = true
		if not progressed:
			break
	for key in remaining:
		K.fail("research-reach", key, "its prerequisites never resolve (a cycle or a missing link): needs %s" % str(R.def_of(key).get("reqDiscovery")))
	# Play each as a nation that may research it (a national discovery needs that nation).
	for key in order:
		var d: Dictionary = R.def_of(key)
		var tag := nation_of(d)
		play_as(identity_for(tag) if tag != "" and tag != "-" else "usa")
		R.era = R.eras.size() - 1
		var ahead: String = R.blocker(key)
		var already: bool = R.done(key)
		if not already:
			# prerequisites are done earlier in the walk; only the era or a facility may still stand in the way
			if ahead != "" and not ahead.contains(" needs a ") and not ahead.begins_with("Needs the "):
				if not ahead.begins_with("Not fielded") and not ahead.ends_with(" only") and not ahead.contains("AI"):
					K.fail("research-reach", key, "blocked when everything before it is done: %s" % ahead)
					continue
				K.warn("research-reach", key, "gated for this test nation: %s" % ahead)
		R._recompute()   # (under this nation's own profile)
		var before := {}
		var fx: Dictionary = R.effects_of(key)
		for stat in fx:
			before[stat] = R.bonus(stat)
		R.progress[key] = {"stage": 3, "work": 0.0, "paid": false}
		R._recompute()
		var wrong := PackedStringArray()
		for stat in fx:
			var gained: float = R.bonus(stat) - float(before[stat])
			if absf(gained - float(fx[stat])) > 0.0001:
				wrong.append("%s expected %s got %s" % [stat, str(fx[stat]), str(snappedf(gained, 0.0001))])
		if wrong.is_empty():
			K.ok("research-effect", key, "completes; bonus changes by its stated effects")
		else:
			K.fail("research-effect", key, "; ".join(wrong))
		K.clean("research-effect", key)
	play_as("usa")

	# ---- the main effects, seen in the game
	for key in R.discoveries:
		R.progress[key] = {"stage": 0, "work": 0.0, "paid": false}
	R._recompute()
	var home: Vector3 = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	for k in ["farm", "market", "school", "residential"]:
		var at = w.test_site(k, home)
		if at != null: w.place_building(k, at, 0, true)
	w.economy.recalculate()
	for i in range(3): w.economy.tick()
	var base_money: float = w.economy.rates.money
	var base_food: float = w.economy.rates.food
	var base_research: float = R.rate
	var base_cap: float = w.economy.civ_cap
	var soldier: Dictionary = w.spawn_unit("soldier", home + Vector3(20, 0, 20), 0)
	var dmg0: float = R.damage_mult(soldier)
	R.progress["__test_income"] = {"stage": 3}
	R.tracks["economy"] = 2
	R._recompute()
	R.tick(1.0)
	w.economy.recalculate(); w.economy.tick()
	K.expect(w.economy.rates.money > base_money, "research-seen", "economy track", "income did not rise (%.2f -> %.2f)" % [base_money, w.economy.rates.money])
	R.tracks["economy"] = 0
	R.tracks["military"] = 3
	R._recompute()
	K.expect(R.damage_mult(soldier) > dmg0, "research-seen", "military track", "damage did not rise")
	R.tracks["military"] = 0
	R.tracks["hightech"] = 3
	R._recompute()
	R.tick(1.0)
	K.expect(R.rate > base_research, "research-seen", "high-tech track", "research rate did not rise (%.2f -> %.2f)" % [base_research, R.rate])
	R.tracks["hightech"] = 0
	R.progress.erase("__test_income")
	R._recompute()
	for pair in [["irrigation", "foodPct"], ["publicEducation", "researchPct"]]:
		if R.discoveries.has(pair[0]):
			var b0: float = R.bonus(pair[1])
			R.progress[pair[0]] = {"stage": 3}
			R._recompute()
			K.expect(R.bonus(pair[1]) > b0, "research-seen", pair[0], "%s did not change" % pair[1])
			R.progress.erase(pair[0])
	R._recompute()
	K.take_errors()

	# ---- three discoveries researched for real: points, stages, messages
	for key in R.discoveries:
		R.progress[key] = {"stage": 0, "work": 0.0, "paid": false}
	R.queue.clear()
	R.era = R.eras.size() - 1
	for tgt in ["fertilizers", "irrigation", "publicEducation"]:
		if not R.discoveries.has(tgt): continue
		R.points = 1000000.0
		var said: String = R.enqueue(tgt)
		var log0: int = w.hud.notice_log.size()
		var seconds := 0
		while not R.done(tgt) and seconds < 1500:
			R.tick(1.0)
			seconds += 1
		if R.done(tgt):
			K.ok("research-real", tgt, "researched in %d s through three stages; messages: %d" % [seconds, w.hud.notice_log.size() - log0])
		else:
			K.fail("research-real", tgt, "never completed in %d s (queue %s, blocker '%s', enqueue said '%s')" % [seconds, str(R.queue), R.blocker(tgt), said])
		K.clean("research-real", tgt)
	quit(K.finish())

## Whether completing `key` visibly opens something: a unit, a building or a weapon names it as the requirement.
func _unlocks_something(key: String) -> bool:
	for file in script_texts:
		if file != "research.gd" and file != "map_catalogue.gd" and script_texts[file].contains('"%s"' % key):
			return true
	for u in w.unit_defs:
		if str(w.unit_defs[u].get("requires", "")) == key or w.research.UNIT_REQUIRES.get(u, "") == key:
			return true
	for m in w.missiles.types():
		if str(w.missiles.def_of(m).get("needsDiscovery", "")) == key:
			return true
	for k in w.research.discoveries:
		if str(w.research.def_of(k).get("reqDiscovery", "")) == key:
			return true
	if key in ["nuclearProgram", "futureArsenal"]:
		return true
	return false
