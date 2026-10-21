extends SceneTree
## Audit of every missile and bomb type (native/ALPHA-1.0-REPORT.md): all of w.missiles.types() (about 30).
## For each: the definition is sane and its help says its role and launcher; the production building exists and lists
## it; which of the 28 national identities can field it; and for an identity that can: the launcher it names exists
## (silo, strategic complex, ship, submarine, aircraft, drone), it launches (one stored weapon is used), it flies and
## lands, and something happens at the target (damage, disabled units, contamination). A weapon that nobody can
## launch, or that does nothing, fails. Table: res://build/audit/missiles.txt
const Kit := preload("res://tools/audit_kit.gd")
const Cheats := preload("res://scripts/cheats.gd")
const Factions := preload("res://scripts/factions.gd")
const Weapon := preload("res://scripts/weapon_copy.gd")
const DT := 1.0 / 30.0
var K
var w: Node
var home: Vector3
var sea: Vector3
func _initialize() -> void: call_deferred("run")

func play_as(id: String) -> void:
	w.map.nations[0]["id"] = id

func settle(seconds: float) -> void:
	for i in range(int(seconds / DT)):
		w.missiles._physics_process(DT)
		w.effects._physics_process(DT)

func clear_field() -> void:
	for u in w.units.duplicate():
		if not u.dead and u.owner != 0 or (not u.dead and u.key in ["jet", "bomber", "stealthFighter", "raider", "drone", "fpvTeam", "destroyer", "nuclearSub", "submarine", "corvette", "aegisCruiser", "missileBoat"]):
			w.kill(u)
	for b in w.buildings.duplicate():
		if not b.dead and b.key != "hq" and (b.owner != 0 or b.key in ["missileSilo", "strategicComplex", "specialLab"]):
			w.destroy_building(b)
	w.missiles.flying.clear()

func land_spot(offset: Vector3) -> Vector3:
	return w.land_point(home + offset, 40.0)

func run() -> void:
	K = Kit.new(self, "missiles")
	w = await K.boot({"map": "island", "players": 3, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	w.effects.set_physics_process(false)
	w.missiles.set_physics_process(false)
	w.ai.set_physics_process(false)
	home = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	Cheats.everything(w)
	w.economy.grant_test_resources()
	for n in w.ai.nations: n.money = 10000000.0
	w.diplomacy.declare_war(0, 1)
	sea = w.water_near(home, 240)
	var ms: Node = w.missiles
	var idents: Array = Factions.IDS.duplicate()
	var keys: Array = ms.types().keys()
	keys.sort()
	K.ok("missiles", "all", "%d weapon types" % keys.size())
	# who can field what
	var able := {}
	var first_id := {}
	for key in keys:
		able[key] = []
	for id in idents:
		play_as(id)
		Cheats.everything(w)
		for key in keys:
			if ms.def_of(key).get("hidden", false):
				continue
			if ms.available_to(0, key) and ms.locked(key) == "":
				able[key].append(id)
	for key in keys:
		var d: Dictionary = ms.def_of(key)
		var problems := PackedStringArray()
		var notes := PackedStringArray()
		var hidden: bool = d.get("hidden", false)
		if str(d.get("name", "")).strip_edges() == "": problems.append("no name")
		if float(d.get("speed", 0)) <= 0.0: problems.append("speed <= 0")
		if float(d.get("radius", 0)) <= 0.0 and not str(d.get("special", "")) in ["emp", "hemp", "poseidon"]: problems.append("radius <= 0")
		if not hidden:
			if not ms.FACILITY.has(ms.category(key)) or not w.building_defs.has(ms.FACILITY[ms.category(key)]): problems.append("no production building")
			if float(d.get("buildTime", 0)) <= 0.0: problems.append("no build time")
			if d.get("cost", {}).is_empty(): problems.append("free")
			var help: String = Weapon.summary(w, key)
			if not (help.contains("Role:") and help.contains("Launch from:")): problems.append("help lacks role or launcher")
			if ms.launchers_text(key) == "": problems.append("no launcher text")
			if able[key].is_empty():
				if preload("res://scripts/cbrn_data.gd").CAPABILITY.get(key, {}).get("ids", ["x"]).is_empty():
					notes.append("no nation fields it by design (no evidence of a national inventory): only a scenario that lists it")
				else:
					problems.append("no nation can field it")
		var detail := "%s, dmg %d radius %d speed %d, cost %s, %s; fielded by %s" % [d.get("name", key), int(d.get("dmg", 0)), int(d.get("radius", 0)), int(d.get("speed", 0)), str(d.get("cost", {})), ms.category(key), "(hidden payload)" if hidden else (str(able[key].size()) + " nations: " + ",".join(PackedStringArray(able[key].slice(0, 5))) + ("..." if able[key].size() > 5 else ""))]
		if problems.is_empty() and not notes.is_empty():
			K.warn("missile-def", key, "; ".join(notes) + " | " + detail)
		elif problems.is_empty():
			K.ok("missile-def", key, detail)
		else:
			K.fail("missile-def", key, "; ".join(problems) + " | " + detail)
	# ---- a launch of each, as a nation that can
	var slot := 0
	for key in keys:
		var d: Dictionary = ms.def_of(key)
		if d.get("hidden", false) or able[key].is_empty():
			continue
		slot += 1
		clear_field()
		if w.wmd != null: w.wmd.zones.clear()
		var id: String = able[key][0]
		play_as(id)
		Cheats.everything(w)
		K.take_errors()
		var kind: String = load("res://scripts/arsenal_catalog.gd").platform_kind(w, 0, key)
		var cat: String = ms.category(key)
		# the launcher
		var launcher = null
		var base := land_spot(Vector3(-60 + (slot % 5) * 25, 0, 40))
		if kind in ["air", "air_or_sea"]:
			launcher = w.spawn_unit("jet", base + Vector3(0, 0, 10), 0)
			launcher.air_state = "parked"
		elif kind == "drone":
			launcher = w.spawn_unit("drone", base, 0)
			launcher.air_state = "ready"
		if kind in ["sea", "sub", "air_or_sea", "ground_or_sea", "strategic"] or cat == "nuclear":
			var sub_key := "nuclearSub" if (kind in ["sub", "strategic"] or cat == "nuclear") else "destroyer"
			if sea != Vector3.INF and launcher == null and kind in ["sea", "sub"]:
				launcher = w.spawn_unit(sub_key, sea, 0)
		if kind in ["ground", "ground_or_sea", "strategic"] or launcher == null:
			var site_key := "missileSilo"
			if cat == "nuclear": site_key = "strategicComplex"
			if cat == "special": site_key = "specialLab"
			var at: Variant = null
			for dq in range(-8, 9):
				for dr in range(-8, 9):
					if at != null: break
					var hex_at: Vector3 = w.logistics.hex_center(w.logistics.world_hex(base) + Vector2i(dq, dr))
					if w.site_problem(site_key, hex_at, 0) == "" or w.site_problem(site_key, hex_at, 0).begins_with("Outside your territory"):
						at = hex_at
			if at != null and launcher == null:
				launcher = w.place_building(site_key, at, 0, true)
		var platforms: Array = ms.platforms_for(key)
		if platforms.is_empty():
			K.fail("missile-launch", key, "%s (%s, platform kind %s) has no launcher in play although the nation fields it" % [id, cat, kind])
			continue
		# the target: a building and troops, or a ship at sea for the anti-ship weapons
		var naval_only: bool = d.get("sub_only", false) or str(d.get("special", "")) in ["antiShip"]
		var target_at := land_spot(Vector3(60, 0, 90))
		var enemy: Dictionary
		if naval_only and sea != Vector3.INF:
			target_at = sea + Vector3(30, 0, 0)
			enemy = w.spawn_unit("destroyer", target_at, 1)
		else:
			var site: Vector3 = w.land_point(target_at, 30.0)
			enemy = w.place_building("barracks", site, 1, true)
			target_at = site
			w.spawn_unit("soldier", site + Vector3(4, 0, 4), 1)
			w.spawn_unit("tank", site + Vector3(-5, 0, 5), 1)
		var radar = null
		if str(d.get("special", "")) == "antiRadar":
			radar = w.spawn_unit("samLauncher", target_at + Vector3(10, 0, 0), 1)
		w.rebuild_grid()
		if cat == "nuclear" and w.get("defcon") != null and w.defcon != null:
			w.defcon.authorise_release()
		ms.stock[key] = 1
		var seen: int = w.intercepts.size()
		var hp0: float = enemy.hp
		var units0: Array = w.units.filter(func(u): return u.owner == 1 and not u.dead).map(func(u): return float(u.hp))
		var said: String = ms.launch(key, target_at)
		if not (said.contains("launched") or said.contains("LAUNCHED")):
			K.fail("missile-launch", key, "did not launch: %s" % said)
			continue
		if int(ms.stock.get(key, 0)) != 0:
			K.fail("missile-launch", key, "the stored weapon was not used (stock %d)" % int(ms.stock.get(key, 0)))
			continue
		var flew: bool = ms.flying.size() > 0
		settle(14.0)
		# A rival's air defence may shoot it down (random by design, air_defence.gd): fire again, up to five more times.
		var shot_down := 0
		while shot_down < 5 and w.intercepts.slice(seen).any(func(i): return str(i.type) == key and i.hit):
			shot_down += 1
			seen = w.intercepts.size()
			ms.stock[key] = 1
			ms.launch(key, target_at)
			settle(14.0)
		var landed: bool = ms.flying.is_empty()
		var hurt: bool = enemy.dead or enemy.hp < hp0 - 0.5
		var troops_hurt := false
		var now: Array = w.units.filter(func(u): return u.owner == 1 and not u.dead)
		if now.size() < units0.size() or (now.size() > 0 and now.any(func(u): return u.hp < u.max_hp - 0.5)):
			troops_hurt = true
		var disabled: bool = w.units.any(func(u): return u.owner == 1 and not u.dead and w.disabled(u)) or w.buildings.any(func(b): return b.owner == 1 and not b.dead and w.disabled(b))
		var contaminated: bool = w.wmd != null and w.wmd.zones.size() > 0
		var witness := PackedStringArray()
		if hurt: witness.append("target %d -> %d" % [int(hp0), int(enemy.hp)])
		if troops_hurt: witness.append("troops hurt")
		if disabled: witness.append("units disabled")
		if contaminated: witness.append("contamination zone")
		var effect := not witness.is_empty()
		if shot_down > 0 and effect: witness.append("shot down %d time(s) by air defence first, then it struck" % shot_down)
		var status := "launched from %s (%s), flew %s, landed %s; %s" % [str(platforms[0].key), kind, str(flew), str(landed), ", ".join(witness) if not witness.is_empty() else "NO EFFECT SEEN"]
		if not flew or not landed:
			K.fail("missile-launch", key, status)
		elif shot_down >= 5 and not effect:
			K.warn("missile-effect", key, status + " (shot down every time: random interception, not a defect)")
		elif not effect:
			K.fail("missile-effect", key, status)
		else:
			K.ok("missile-effect", key, status)
		K.clean("missile-effect", key)
		if radar != null and not radar.dead:
			pass
	clear_field()
	# ---- the message for a missing launcher, for each kind
	play_as("usa")
	for key in ["tactical", "antiRadar", "nuke", "poseidon"]:
		if ms.types().has(key):
			var none: String = ms.launcher_missing(key) if ms.platforms_for(key).is_empty() else "has a launcher"
			K.expect(none != "" and not none.contains("Needs a compatible"), "missile-message", key, "launcher text: '%s'" % none)
	quit(K.finish())
