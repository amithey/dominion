extends SceneTree
## The explosion looks (scripts/blasts.gd, effects.blast): every look is built from known layers, palettes and films;
## every munition and warhead that is seen to burst names a look that exists and every look is used; a burst plays its
## munition's look; ground layers stay off a burst in the air, the sea answers a burst at its surface; craters follow the
## munition, not the look; a shaped charge throws its spall back the way the round came; delayed layers play and
## everything is cleared away afterwards; the Low preset leaves out the costly layers.
## Run: Godot --headless --path native/godot --script res://tools/explosion-check.gd
var w: Node
var errors: Array[String] = []
var passed := 0
const F := preload("res://scripts/firepower.gd")
const B := preload("res://scripts/blasts.gd")
const DT := 1.0 / 30.0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func step(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		w.effects._physics_process(DT)
		t += DT

func craters() -> int:
	return w.battle_scars._pool.size()

func run() -> void:
	seed(7)
	set_meta("match_config", {"map": "island", "players": 2, "nation": 0, "opening": "light", "style": "sandbox"})
	change_scene_to_file("res://world.tscn")
	for i in range(40000):
		await process_frame
		if current_scene != null and current_scene.get("nav_ready") == true and current_scene.get("menu") != null:
			w = current_scene
			break
	w.start_match("easy")
	w.menu.close()
	preload("res://tools/test_kit.gd").quiet(w)
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.effects.force_books = true   # the filmed layers too, in a headless run
	var fx: Node = w.effects
	var bl: Node = fx.blasts

	# ------------------------------------------------------------ 1. the looks are built from what exists
	var bad := PackedStringArray()
	for look in B.LOOKS:
		var layers: Array = B.LOOKS[look]
		if layers.is_empty():
			bad.append("%s is empty" % look)
		for entry in layers:
			var layer: String = entry[0]
			var p: Dictionary = entry[1]
			if not layer in B.LAYERS:
				bad.append("%s: unknown layer '%s'" % [look, layer])
			if p.has("pal") and not B.PALETTES.has(str(p.pal)):
				bad.append("%s: unknown palette '%s'" % [look, p.pal])
			if layer == "book" and not fx.BOOKS.has(str(p.get("kind", ""))):
				bad.append("%s: unknown film '%s'" % [look, p.get("kind", "")])
			if p.has("film") and str(p.film) != "" and not fx.BOOKS.has(str(p.film)):
				bad.append("%s: unknown film '%s'" % [look, p.film])
			if layer == "pops" and not B.LOOKS.has(str(p.get("look", "bomblet"))):
				bad.append("%s: pops of an unknown look '%s'" % [look, p.get("look", "")])
			if float(p.get("delay", 0.0)) < 0.0 or float(p.get("delay", 0.0)) > 3.0:
				bad.append("%s: %s delayed %s s" % [look, layer, p.get("delay")])
	for pal in B.PALETTES:
		if not fx.BOOKS.has(str(B.PALETTES[pal][1])):
			bad.append("palette %s: unknown film '%s'" % [pal, B.PALETTES[pal][1]])
	check(bad.is_empty(), "every look is built from known layers, palettes and films (%d looks)%s" % [B.LOOKS.size(), "" if bad.is_empty() else ": " + "; ".join(bad)])

	# ------------------------------------------------------------ 2. munitions and warheads name looks; every look is used
	check(F.problems().is_empty(), "every munition and warhead that is seen names a look that exists%s" % ("" if F.problems().is_empty() else ": " + "; ".join(F.problems())))
	var used := {"classic": true}   # (the burst of anything that names no look)
	for key in F.keys():
		if float(F.profile(key).fx) > 0.0:
			used[str(F.profile(key).look)] = true
	for special in F.WARHEADS:
		used[str(F.warhead(special).look)] = true
		used[str(F.warhead(special, true).look)] = true
	for look in B.LOOKS:
		for entry in B.LOOKS[look]:
			if entry[0] == "pops":
				used[str(entry[1].get("look", "bomblet"))] = true
	var idle := PackedStringArray()
	for look in B.LOOKS:
		if not used.has(look):
			idle.append(look)
	check(idle.is_empty(), "every look is some weapon's (no look lies unused)%s" % ("" if idle.is_empty() else ": " + ", ".join(idle)))
	var kinds := {}
	for key in ["grenade", "shell", "rocket", "mortar", "shell_arc", "bomb", "thermobaric", "sam", "torpedo"]:
		kinds[str(F.profile(key).look)] = true
	check(kinds.size() == 9, "a grenade, a tank shell, an anti-tank rocket, a mortar bomb, a howitzer shell, a bomb, a fuel-air rocket, a missile at an aircraft and a torpedo each look different (%d looks)" % kinds.size())

	# ------------------------------------------------------------ 3. a burst plays its munition's look
	var field: Vector3 = w.land_point(w.start + Vector3(-70, 0, 50), 40.0)
	field.y = w.height_at(field.x, field.z)
	var gunner: Dictionary = w.spawn_unit("artillery", field + Vector3(-12, 0, 0), 0)
	var wrong := PackedStringArray()
	for key in F.keys():
		var p: Dictionary = F.profile(key)
		if float(p.fx) <= 0.0:
			continue
		var before: int = int(bl.played.get(str(p.look), 0))
		F.detonate(w, gunner, key, field + Vector3(0, 0, 30), 0.0)
		if int(bl.played.get(str(p.look), 0)) != before + 1:
			wrong.append("%s did not play '%s'" % [key, p.look])
	check(wrong.is_empty(), "every munition that is seen plays its own look%s" % ("" if wrong.is_empty() else ": " + ", ".join(wrong)))
	step(60.0)

	# ------------------------------------------------------------ 4. ground, air and sea; craters follow the munition
	var c0 := craters()
	F.detonate(w, gunner, "shell_arc", field, 0.0)
	check(craters() == c0 + 1, "a howitzer shell on the ground leaves a crater")
	c0 = craters()
	F.detonate(w, gunner, "grenade", field + Vector3(4, 0, 0), 0.0)
	check(craters() == c0, "a grenade does not (its profile says so, whatever its look)")
	c0 = craters()
	var scorch0: int = fx._live.filter(func(e): return e.kind == "scorch").size()
	F.detonate(w, gunner, "sam", field + Vector3(0, 20, 0), 0.0)
	check(craters() == c0 and fx._live.filter(func(e): return e.kind == "scorch").size() == scorch0, "a missile bursting 20 m up leaves no crater and no scorch on the ground")
	c0 = craters()
	F.strategic(w, "test", {"radius": 15.0, "dmg": 0.0, "special": "cluster"}, field + Vector3(0, 0, 60), 0)
	F.strategic(w, "test", {"radius": 15.0, "dmg": 0.0, "special": "chemical"}, field + Vector3(0, 0, -60), 0)
	check(craters() == c0, "a cluster warhead and a chemical one leave no big crater")
	F.strategic(w, "test", {"radius": 15.0, "dmg": 0.0}, field + Vector3(30, 0, 60), 0)
	check(craters() == c0 + 1, "a plain warhead does")
	var sea = w.water_near(w.start, 220)
	if sea != null:
		var at_sea := Vector3(sea.x, float(w.map.seaLevel), sea.z)
		var spray0: int = fx._live.filter(func(e): return e.node is GPUParticles3D and (e.node as GPUParticles3D).process_material == bl._spray).size()
		c0 = craters()
		F.detonate(w, gunner, "shell", at_sea, 0.0)
		var spray: int = fx._live.filter(func(e): return e.node is GPUParticles3D and (e.node as GPUParticles3D).process_material == bl._spray).size()
		check(spray > spray0 and craters() == c0, "a shell bursting at the sea's surface throws up water and leaves no crater")
	else:
		check(true, "(no sea near the capital to burst a shell on)")

	# ------------------------------------------------------------ 5. the spall of a shaped charge goes back the way the round came
	var cache_before: Array = bl._streaks.keys()
	var shooter: Dictionary = w.spawn_unit("atgmTeam", field + Vector3(-25, 0, 40), 0)
	F.detonate(w, shooter, "atgm", field + Vector3(0, 0, 40), 0.0)
	var back := false
	for key in bl._streaks:
		if not key in cache_before and (bl._streaks[key] as ParticleProcessMaterial).direction.x < -0.3:
			back = true
	check(back, "an anti-tank missile's spall flies back toward the team that fired it")

	# ------------------------------------------------------------ 6. delayed layers play; nothing is left behind
	step(60.0)
	for i in range(3): await process_frame   # (what was freed leaves the tree at the end of a frame)
	var base_live: int = fx._live.size()
	var base_nodes: int = fx.get_child_count() + bl.get_child_count()
	var lights0: int = fx._live.filter(func(e): return e.kind == "light").size()
	fx.blast("thermobaric", field + Vector3(-40, 0, 0), 1.4)
	var waiting: int = bl._wait.size()
	var lit_at_once: int = fx._live.filter(func(e): return e.kind == "light").size()
	step(0.4)
	check(waiting > 0 and lit_at_once == lights0 and fx._live.filter(func(e): return e.kind == "light").size() > lights0, "a fuel-air burst spreads its cloud first and ignites a moment later")
	step(60.0)
	for i in range(3): await process_frame
	check(bl.busy() == 0 and fx._live.size() <= base_live and fx.get_child_count() + bl.get_child_count() <= base_nodes, "everything a burst leaves is cleared away within a minute (%d effects, %d nodes)" % [fx._live.size(), fx.get_child_count() + bl.get_child_count()])

	# ------------------------------------------------------------ 7. the Low preset
	var quality: String = w.quality
	fx.blast("bomb", field + Vector3(40, 0, 0), 1.6)
	var domes_high: int = bl._live.size()
	var live_high: int = fx._live.size()
	step(60.0)
	w.quality = "low"
	var live_low0: int = fx._live.size()
	fx.blast("bomb", field + Vector3(40, 0, 0), 1.6)
	check(domes_high > 0 and bl._live.size() == 0, "on Low a bomb has no pressure dome")
	check(fx._live.size() - live_low0 < live_high - base_live, "and fewer layers (%d against %d)" % [fx._live.size() - live_low0, live_high - base_live])
	w.quality = quality
	step(60.0)

	print("EXPLOSIONS %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("EXPLOSION_CHECK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
