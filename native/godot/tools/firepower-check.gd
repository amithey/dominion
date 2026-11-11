extends SceneTree
## The firepower template (scripts/firepower.gd, native/FIREPOWER-PHYSICS.md): every weapon has a profile, the profiles are
## sound, and a burst behaves as its profile says.
##   1. every unit of every nation and every strategic missile resolves to a munition with a profile;
##   2. no profile has an unknown field or a number out of range;
##   3. the physics: full effect at the centre, never rising with distance, nothing beyond the radius; fragments reach past the
##      blast and find only men in the open; a bigger warhead throws harder; an air burst leaves the roads and the ground alone;
##      what burns is the munition's to say; a custom on_detonate can replace the standard burst.
## Run: Godot --headless --path native/godot --script res://tools/firepower-check.gd
var w: Node
var errors: Array[String] = []
var passed := 0
const F := preload("res://scripts/firepower.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if ok: passed += 1
	else: errors.append(label)

func run() -> void:
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
	w.ai.set_physics_process(false)
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.diplomacy.declare_war(0, 1, "test")

	# ------------------------------------------------------------ 1. every weapon has a profile
	var missing := PackedStringArray()
	var weapons := {}
	for key in w.unit_defs.keys():
		var weapon: String = F.weapon_of(w, key)
		if weapon == "":
			continue
		weapons[weapon] = true
		if not F.has(weapon):
			missing.append("%s fires '%s'" % [key, weapon])
	check(missing.is_empty(), "every unit's weapon has a munition profile (%d units carry %d weapons)%s" % [w.unit_defs.size(), weapons.size(), "" if missing.is_empty() else ": " + ", ".join(missing)])
	check(F.has("bullet") and F.has("shell"), "small arms and plain guns have their profiles")
	var no_fire := PackedStringArray()
	for key in w.missiles.types():
		var def: Dictionary = w.missiles.def_of(key)
		var src := {"key": "missile", "special": def.get("special", ""), "nuclear": key == "nuke" or def.get("nuclear", false)}
		if F.fire_of_source(src) < 0.0:
			no_fire.append(key)
	check(no_fire.is_empty(), "every strategic missile says what it sets alight (%d missiles)%s" % [w.missiles.types().size(), "" if no_fire.is_empty() else ": " + ", ".join(no_fire)])

	# ------------------------------------------------------------ 2. the profiles are sound
	var wrong: PackedStringArray = F.problems()
	check(wrong.is_empty(), "no profile has an unknown field or a number out of range (%d profiles)%s" % [F.keys().size(), "" if wrong.is_empty() else ": " + "; ".join(wrong)])

	# ------------------------------------------------------------ 3. the physics
	var monotone := true
	var centre := true
	var beyond := true
	for key in F.keys():
		var p: Dictionary = F.profile(key)
		if float(p.radius) <= 0.0:
			continue
		if F.falloff(p, 0.0) != 1.0: centre = false
		if F.falloff(p, float(p.radius) * 1.001) != 0.0: beyond = false
		var last := 1.0
		for i in range(1, 41):
			var v: float = F.falloff(p, float(p.radius) * i / 41.0)
			if v > last + 0.0001: monotone = false
			last = v
	check(centre and beyond, "full effect at the centre, none past the radius")
	check(monotone, "the effect never rises with distance")
	check(float(F.profile("grenade").radius) < float(F.profile("shell_arc").radius) and float(F.profile("shell_arc").radius) < float(F.profile("bomb").radius), "a grenade reaches less than a shell, a shell less than a bomb")
	check(float(F.profile("thermobaric").edge) > float(F.profile("shell_arc").edge), "a fuel-air cloud holds its pressure to the rim where high explosive falls away")
	check(float(F.profile("grenade").fire) < float(F.profile("thermobaric").fire) and F.fire_of_source({"key": "missile", "nuclear": true}) >= 1.3 and F.fire_of_source({"key": "missile", "special": "emp"}) == 0.0, "a thermobaric rocket and a nuclear burst start fires a grenade does not; a pulse starts none")

	# a burst among men: the fall-off, the fragments, the shove
	var field: Vector3 = w.land_point(w.start + Vector3(-70, 0, 50), 40.0)
	var gunner: Dictionary = w.spawn_unit("artillery", field + Vector3(0, 0, -60), 0)
	var at: Vector3 = field
	at.y = w.height_at(at.x, at.z)
	var p_shell: Dictionary = F.profile("shell_arc")
	var r: float = p_shell.radius
	var men := {}
	for spot in [["centre", 0.4], ["mid", r * 0.7], ["rim", r * 0.97], ["fragments", r * 1.3], ["clear", r * float(p_shell.frag) + 1.5]]:
		var u: Dictionary = w.spawn_unit("soldier", at + Vector3(float(spot[1]), 0, 0), 1)
		u.max_hp = 100000.0
		u.hp = 100000.0
		men[spot[0]] = u
	var hull: Dictionary = w.spawn_unit("tank", at + Vector3(0, 0, r * 1.3), 1)
	hull.max_hp = 100000.0
	hull.hp = 100000.0
	F.detonate(w, gunner, "shell_arc", at, 1000.0)
	var lost := {}
	for name in men:
		lost[name] = 100000.0 - float(men[name].hp)
	check(lost.centre > lost.mid and lost.mid > lost.rim and lost.rim > 0.0, "a shell hurts most at the centre and less toward the rim (%d, %d, %d)" % [int(lost.centre), int(lost.mid), int(lost.rim)])
	check(lost.fragments > 0.0 and lost.fragments < lost.rim, "its fragments reach a man past the blast, lightly (%d)" % int(lost.fragments))
	check(lost.clear == 0.0, "and no farther")
	check(float(hull.hp) == 100000.0, "fragments do nothing to a tank at the same distance")
	check(Vector3(men.centre.get("knock", Vector3.ZERO)).length() > Vector3(men.rim.get("knock", Vector3.ZERO)).length(), "the blast throws the nearest man hardest")
	check(str(gunner.get("munition", "")) == "shell_arc", "the gun remembers what it fired (what burns is the munition's to say)")
	var one: Dictionary = w.spawn_unit("soldier", at + Vector3(40, 0, 0), 1)
	var two: Dictionary = w.spawn_unit("soldier", at + Vector3(60, 0, 0), 1)
	for u in [one, two]:
		u.max_hp = 100000.0
		u.hp = 100000.0
	F.detonate(w, gunner, "grenade", one.node.position + Vector3(1.0, 0, 0), 100.0)
	F.detonate(w, gunner, "bomb", two.node.position + Vector3(1.0, 0, 0), 100.0)
	check(Vector3(two.get("knock", Vector3.ZERO)).length() > Vector3(one.get("knock", Vector3.ZERO)).length() * 1.5, "a bomb throws a man harder than a grenade at the same distance")

	# an air burst: nothing to the road below; a ground burst wears it
	var lg = w.logistics
	var hex: Vector2i = lg.world_hex(at + Vector3(0, 0, 90))
	var edge := {"a": hex, "b": hex + Vector2i(1, 0), "owner": 1, "kind": "road", "hp": 1.0e6, "max_hp": 1.0e6, "half": [1.0e6, 1.0e6]}
	lg.edges["firepower-check"] = edge
	var road_at: Vector3 = lg.hex_center(hex)
	road_at.y = w.height_at(road_at.x, road_at.z)
	F.detonate(w, gunner, "sam", road_at + Vector3.UP * 20.0, 5000.0)
	var after_air: float = edge.half[0]
	F.detonate(w, gunner, "grenade", road_at, 5000.0)
	var after_grenade: float = edge.half[0]
	F.detonate(w, gunner, "shell_arc", road_at, 5000.0)
	var after_ground: float = edge.half[0]
	check(after_air == 1.0e6, "a missile bursting 20 m up does nothing to the road below")
	check(after_grenade == 1.0e6, "nor does a grenade on it")
	check(after_ground < after_grenade, "a shell on the ground wears the road (%d)" % int(after_grenade - after_ground))
	lg.edges.erase("firepower-check")

	# a weapon with something of its own
	var seen := []
	F.register("test_dud", {"kind": "he", "radius": 4.0, "fx": 0.0, "on_detonate": func(_world, _shooter, where, dmg) -> bool:
		seen.append([where, dmg])
		return true})
	var bystander: Dictionary = w.spawn_unit("soldier", at + Vector3(0, 0, 40), 1)
	var hp0: float = bystander.hp
	F.detonate(w, gunner, "test_dud", bystander.node.position, 500.0)
	check(seen.size() == 1 and bystander.hp == hp0, "a munition's own on_detonate runs and may replace the standard burst")
	check(F.problems().is_empty(), "a registered munition is checked like the rest")
	F.unregister("test_dud")
	check(not F.has("test_dud"), "and can be taken away again")

	print("FIREPOWER %d passed, %d failed" % [passed, errors.size()])
	for e in errors: print("  FAILED: " + e)
	print("FIREPOWER_CHECK %s" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)
