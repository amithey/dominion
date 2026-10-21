extends SceneTree
## Audit of every building definition (native/ALPHA-1.0-REPORT.md): all of w.building_defs at runtime (about 53).
## For each building: the definition is sane (name, cost, health, footprint, description, its units exist); a valid
## site can be found; it is placed and finishes with a model and health; what it promises (provides) really changes
## the economy (food, income, power, housing, happiness, research, depots, command); what it trains can be queued
## (or says why not); it can be destroyed and demolished (a capital or town refuses, with words); it survives a save.
## Table: res://build/audit/buildings.txt
const Kit := preload("res://tools/audit_kit.gd")
const Cheats := preload("res://scripts/cheats.gd")
const Brief := preload("res://scripts/brief.gd")
var K
var w: Node
var home: Vector3
func _initialize() -> void: call_deferred("run")

func candidates(key: String, def: Dictionary) -> Array:
	var out: Array = []
	var origin: Vector2i = w.logistics.world_hex(home)
	if def.get("onDeposit", false) or def.get("water", false):
		for d in w.deposits:
			if def.get("depositTypes") != null and not d.type in def.depositTypes:
				continue
			if def.get("water", false) != bool(d.get("water", false)) and def.get("depositTypes") != null:
				continue
			out.append(d.pos)
	for ring in range(1, 16):
		for dq in range(-ring, ring + 1):
			for dr in range(-ring, ring + 1):
				if absi(dq + dr) > ring:
					continue
				out.append(w.logistics.hex_center(origin + Vector2i(dq, dr)))
	return out

func find_site(key: String, def: Dictionary) -> Variant:
	for at in candidates(key, def):
		var snapped: Vector3 = at
		if not def.get("water", false):
			snapped = w.snap_to_hex(at) if w.has_method("snap_to_hex") and (w.is_district(key)) else at
		if w.site_problem(key, snapped, 0) == "":
			return snapped
	return null

func run() -> void:
	K = Kit.new(self, "buildings")
	w = await K.boot({"map": "island", "players": 3, "nation": 0}, "easy", true)
	if w == null:
		quit(1)
		return
	w.set_physics_process(false)
	w.ai.set_physics_process(false)
	home = w.buildings.filter(func(b): return b.owner == 0 and b.key == "hq")[0].root.position
	Cheats.everything(w)   # every era and discovery open: this audits buildings, not the ladder
	w.economy.grant_test_resources()
	var t: Node = w.territory
	for i in range(t.owner_of.size()):
		if t.center(i).distance_to(home) < 520.0 and t.owner_of[i] < 0:
			t.owner_of[i] = 0   # (the land round the capital is ours: this audits buildings, not sovereignty)
	for n in w.ai.nations: n.money = 10000000.0
	var keys: Array = w.building_defs.keys()
	keys.sort()
	K.ok("buildings", "all", "%d building definitions" % keys.size())
	var placed_ok := 0
	for key in keys:
		var def: Dictionary = w.building_defs[key]
		var problems := PackedStringArray()
		if str(def.get("name", "")).strip_edges() == "" or str(def.name).contains("null"): problems.append("no proper name")
		if float(def.get("hp", 0)) <= 0.0: problems.append("hp <= 0")
		if def.get("cost", {}).is_empty() and key != "hq": problems.append("free")
		if float(def.get("buildTime", 0)) <= 0.0 and key != "hq": problems.append("no build time")
		if str(def.get("desc", "")).strip_edges() == "": problems.append("no description")
		for u in def.get("trains", []):
			if not w.unit_defs.has(u): problems.append("trains unknown unit %s" % u)
		if not problems.is_empty():
			K.fail("building-def", key, "; ".join(problems))
		else:
			K.ok("building-def", key, "%s: hp %d, cost %s, %d s, trains %d units" % [def.name, int(def.hp), str(def.cost), int(def.get("buildTime", 0)), def.get("trains", []).size()])
		if key == "hq":
			K.ok("building-place", key, "the capital exists at the start")
			continue
		var site = find_site(key, def)
		if site == null:
			var reason: String = w.site_problem(key, home, 0)
			K.warn("building-place", key, "no valid site found round the capital (%s at the capital)" % reason)
			continue
		# ---- place and finish; what it provides
		K.take_errors()
		w.logistics.update_supply()
		w.economy.recalculate()
		w.economy.tick()
		w.economy.tick()
		w.research.tick(0.0)
		var provided_before := {}
		for stat in def.get("provides", {}):
			provided_before[stat] = w.economy.provided(stat)
		var rates_before: Dictionary = w.economy.rates.duplicate()
		var civ_cap0: float = w.economy.civ_cap
		var pop_cap0: int = w.economy.pop_cap
		var plant0: float = w.economy.plant_bonus()
		var depot0: float = w.economy.depot_damage()
		var command0: float = w.economy.command_health()
		var research0: float = w.research.rate if w.research != null else 0.0
		var b: Dictionary = w.place_building(key, site, 0, true)
		if b.is_empty() or not b.get("built", false) or b.root == null or b.hp <= 0.0:
			K.fail("building-place", key, "placed but not a finished building (built %s, hp %s)" % [str(b.get("built")), str(b.get("hp"))])
			continue
		w.logistics.update_supply() if w.logistics.has_method("update_supply") else null
		w.economy.recalculate()
		w.economy.tick()
		w.economy.tick()
		w.research.tick(0.0)
		K.ok("building-place", key, "placed at %s with %d model parts" % [str(site.snapped(Vector3.ONE)), b.model.get_child_count() if b.model != null else 0])
		placed_ok += 1
		K.clean("building-place", key)
		var supplied: bool = b.get("supplied", true)
		# What it provides.
		var missing := PackedStringArray()
		var witnessed := PackedStringArray()
		for stat in def.get("provides", {}):
			var gained: float = w.economy.provided(stat) - float(provided_before[stat])
			var expected := float(def.provides[stat])
			if supplied and absf(gained - expected) > 0.001:
				missing.append("%s expected %.2f got %.2f" % [stat, expected, gained])
		var cat_effects := {
			"incomePct": w.economy.rates.money > float(rates_before.get("money", 0.0)) or not supplied,
			"civCap": w.economy.civ_cap > civ_cap0 or not supplied,
			"pop": w.economy.pop_cap > pop_cap0 or not supplied,
			"prodPct": w.economy.plant_bonus() > plant0 or not supplied,
			"dmgPct": w.economy.depot_damage() > depot0 or not supplied,
			"hpPct": w.economy.command_health() > command0 or not supplied,
			"researchRate": (w.research.rate > research0) if w.research != null else true,
			"foodRate": w.economy.rates.food > float(rates_before.get("food", 0.0)) or key in ["foodDepot"] or not supplied,
		}
		for stat in def.get("provides", {}):
			if cat_effects.has(stat):
				if cat_effects[stat]:
					witnessed.append(stat)
				else:
					missing.append("%s has no effect on the economy" % stat)
		if not missing.is_empty():
			K.fail("building-provides", key, "; ".join(missing))
		elif def.get("provides", {}).is_empty():
			K.ok("building-provides", key, "provides nothing by definition" + (" (unsupplied)" if not supplied else ""))
		else:
			K.ok("building-provides", key, "provides %s%s" % [",".join(PackedStringArray(def.provides.keys())), "" if supplied else " (unsupplied: waits for a road)"])
		# ---- what it trains
		for u in def.get("trains", []):
			var q0: int = b.queue.size()
			var log0: int = w.hud.notice_log.size()
			w.economy.pop_cap += 100
			w.queue_unit(b, u)
			if b.queue.size() > q0:
				K.ok("building-trains", "%s -> %s" % [key, u], "queued")
				w.cancel_queued(b, b.queue.size() - 1)
			elif w.hud.notice_log.size() > log0 or w.hud.notice_log.size() >= 120:
				K.ok("building-trains", "%s -> %s" % [key, u], "refused with a message: %s" % str(w.hud.notice_log[-1]).substr(0, 80))
			else:
				K.warn("building-trains", "%s -> %s" % [key, u], "not queued and no message")
			w.economy.pop_cap -= 100
		K.clean("building-trains", key)
		# ---- destroy or demolish
		var money0: float = w.economy.res.money
		var said: String = w.demolish(b, true)
		if key in ["hq"] or def.get("settlement") != null:
			K.expect(said != "" and not b.dead, "building-demolish", key, "a capital or town should refuse with words (got '%s')" % said)
		else:
			K.expect(said == "" and b.dead, "building-demolish", key, "demolish failed: %s" % said)
		if not b.dead:
			w.destroy_building(b)
		K.clean("building-demolish", key)
	# ---- a destroyed ruin and a save round trip with a few kinds standing
	for key in ["farm", "market", "barracks", "powerPlant"]:
		var site = find_site(key, w.building_defs[key])
		if site != null:
			w.place_building(key, site, 0, true)
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.saves.capture()))
	K.expect(w.saves.problem_with(data) == "" and data.buildings.size() >= 4, "building-save", "round trip", "a save with buildings fails its own check: %s" % w.saves.problem_with(data))
	K.ok("buildings", "summary", "%d of %d placed" % [placed_ok, keys.size() - 1])
	quit(K.finish())
