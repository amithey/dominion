extends RefCounted
## Urban Garrisoning (Track 3A):
## Infantry squads (soldier, sniper, rocketSoldier, atgmTeam, manpads, commando,
## mortarTeam, fpvTeam, medic...) can enter intact friendly urban buildings for
## fortified cover (-55% damage taken) and elevated firing angles (+20% weapon
## & sight range). If the building catches heavy fire (fire >= 0.35) or collapses,
## garrisoned squads automatically evacuate onto the surrounding street.

const GARRISON_CAPS := {
	"cottage": 2, "workerHouse": 2, "luxuryVillas": 2, "housing": 3, "residential": 3,
	"apartments": 4, "villageCenter": 3, "cityCenter": 4, "hq": 4, "cityHall": 3,
	"courthouse": 3, "bank": 3, "stockExchange": 3, "tvStation": 3, "techPark": 3,
	"intelAgency": 3, "school": 3, "library": 3, "university": 4, "hospital": 2,
	"policeStation": 3, "fireStation": 2, "warehouse": 3, "foodDepot": 2,
	"barracks": 4, "commandCenter": 4, "embassy": 2, "museum": 3,
}
const COVER_MULT := 0.45      # 55% incoming damage reduction while fortified indoors
const RANGE_BONUS := 1.20     # +20% elevated window weapon & sight reach
const FIRE_EVAC_AT := 0.35    # evacuate when building flames reach 35%

static func capacity_of(b: Dictionary) -> int:
	if b == null or b.get("dead", false) or not b.get("built", false):
		return 0
	if float(b.get("fire", 0.0)) >= FIRE_EVAC_AT:
		return 0
	return int(GARRISON_CAPS.get(str(b.get("key", "")), 0))

static func occupants(b: Dictionary) -> Array:
	if not b.has("garrison"):
		b.garrison = []
	var alive: Array = []
	for u in b.garrison:
		if u != null and not u.get("dead", false) and is_same(u.get("garrison_building"), b):
			alive.append(u)
	b.garrison = alive
	return alive

static func room(b: Dictionary) -> int:
	return maxi(0, capacity_of(b) - occupants(b).size())

static func can_garrison(w: Node, u: Dictionary, b: Dictionary) -> bool:
	if u == null or b == null or u.get("dead", false) or b.get("dead", false) or not b.get("built", false):
		return false
	if int(u.owner) != int(b.owner) or u.get("stowed", false) or u.get("garrison_building") != null:
		return false
	if u.get("fly", false) or u.get("naval", false) or u.get("vehicle", false):
		return false
	var key := str(u.get("key", ""))
	if key == "worker" or not (key in w.infantry_keys):
		return false
	return capacity_of(b) > 0

static func order_garrison(w: Node, units_list: Array, b: Dictionary) -> int:
	var count := 0
	for u in units_list:
		if not can_garrison(w, u, b):
			continue
		u.garrison_order = b
		u.enemy = null
		u.attack_move = false
		var stand: Vector3 = w._approach_candidate(b, u.node.position, count) if w.has_method("_approach_candidate") else b.root.position
		w.order_move([u], stand)
		u.garrison_order = b   # (after the move order, which clears it)
		count += 1
	if count > 0 and int(b.owner) == 0 and w.get("hud") != null and w.hud != null:
		w.hud.notice("%d squad%s ordered to garrison %s." % [count, "" if count == 1 else "s", str(b.def.name)])
	return count

static func enter(w: Node, u: Dictionary, b: Dictionary) -> bool:
	if not can_garrison(w, u, b) or room(b) <= 0:
		u.erase("garrison_order")
		return false
	u.erase("garrison_order")
	var list := occupants(b)
	var slot := list.size()
	list.append(u)
	b.garrison = list
	u.garrison_building = b
	u.pre_garrison_range = float(u.range)
	u.range = float(u.range) * RANGE_BONUS
	u.target = null
	u.path = PackedVector3Array()
	u.moving = false
	u.selected = false
	if u.get("ring") != null:
		u.ring.visible = false
	u.node.visible = false
	var angle := TAU * float(slot) / maxf(float(capacity_of(b)), 1.0)
	u.node.position = b.root.position + Vector3(cos(angle) * 2.2, 2.8, sin(angle) * 2.2)
	return true

static func exit_unit(w: Node, u: Dictionary, b: Dictionary, idx := 0, emergency := false) -> void:
	if u == null:
		return
	if u.has("pre_garrison_range"):
		u.range = float(u.pre_garrison_range)
		u.erase("pre_garrison_range")
	u.erase("garrison_building")
	u.erase("garrison_order")
	if u.get("dead", false):
		return
	var centre: Vector3 = b.root.position if b != null and b.get("root") != null else u.node.position
	var fp: float = float(b.get("footprint", 12.0)) if b != null else 10.0
	var out_r := fp * 0.55 + 4.2
	var placed := centre + Vector3(out_r, 0.0, 0.0)
	for step in range(12):
		var a := float(idx) * 1.15 + float(step) * (TAU / 12.0)
		var cand := Vector3(centre.x + cos(a) * out_r, 0.0, centre.z + sin(a) * out_r)
		var h: float = w.height_at(cand.x, cand.z)
		if h > float(w.map.seaLevel) + 0.25:
			cand.y = h
			placed = cand
			break
	placed.y = w.height_at(placed.x, placed.z)
	u.node.position = placed
	u.node.visible = (not w.fog.enabled) or w.fog.shows(u) if w.get("fog") != null else true
	if emergency and not u.dead:
		u.hp = maxf(1.0, float(u.hp) - float(u.max_hp) * 0.08)

static func evacuate(w: Node, b: Dictionary, emergency := false) -> int:
	if b == null or not b.has("garrison"):
		return 0
	var list: Array = b.garrison.duplicate()
	b.garrison = []
	var n := 0
	for i in range(list.size()):
		var u: Dictionary = list[i]
		if u != null and is_same(u.get("garrison_building"), b):
			exit_unit(w, u, b, i, emergency)
			n += 1
	if n > 0 and int(b.owner) == 0 and w.get("hud") != null and w.hud != null:
		if emergency:
			w.hud.notice("Garrison evacuated from %s due to fire or collapse." % str(b.def.name))
	return n

static func update(w: Node, _delta: float) -> void:
	# 1. Check units marching to garrison a building
	for u in w.units:
		if u.dead:
			continue
		if u.has("garrison_order"):
			var gb: Dictionary = u.garrison_order
			if gb == null or gb.get("dead", false) or not gb.get("built", false) or room(gb) <= 0:
				u.erase("garrison_order")
				u.target = null
				continue
			var reach: float = (w.site_reach(gb) + 2.5) if w.has_method("site_reach") else float(gb.get("footprint", 12.0)) * 0.52 + 5.5
			var d := Vector2(u.node.position.x - gb.root.position.x, u.node.position.z - gb.root.position.z).length()
			if d <= reach:
				enter(w, u, gb)
		elif u.get("garrison_building") != null:
			var b: Dictionary = u.garrison_building
			if b.get("dead", false) or float(b.get("fire", 0.0)) >= FIRE_EVAC_AT:
				evacuate(w, b, true)

	# 2. Check burning or collapsed buildings that still hold garrisoned squads
	for b in w.buildings:
		if b.has("garrison") and not (b.garrison as Array).is_empty():
			if b.get("dead", false) or float(b.get("fire", 0.0)) >= FIRE_EVAC_AT:
				evacuate(w, b, true)

## Splash bleed-through when an occupied building is struck by heavy weapons.
static func on_building_hit(w: Node, b: Dictionary, raw_amount: float, source: Dictionary) -> void:
	var list := occupants(b)
	if list.is_empty() or raw_amount <= 2.0:
		return
	var each := (raw_amount * COVER_MULT * 0.30) / maxf(float(list.size()), 1.0)
	for u in list.duplicate():
		if not u.dead:
			u.hp -= each
			if u.hp <= 0.0:
				exit_unit(w, u, b, 0, false)
				w.damage(u, 9999.0, source)
