extends RefCounted
## Nuclear tests: a nuclear-armed nation may test a device on its own land.
## Research and sources: native/CBRN-UN-RESEARCH-2026-10-05.md.
##
##   underground   the device is buried: the shock is felt and measured by every
##                 seismograph in the world, but almost nothing escapes
##   atmospheric   a full burst in the open: a mushroom cloud and a fallout that
##                 drifts with the wind, over neighbours too
## What a test gives: proof that the weapon works. Rivals believe the deterrent
## (for 15 minutes they are far slower to start a war with the tester, and a
## rival weighing a nuclear strike on it weighs it again), and the scientists
## learn from it (research points).
## What it costs: the device (money and uranium), the world's opinion (testing is
## banned by treaty; the atmosphere far more so), nuclear tension, and the
## Security Council, which takes up any test (sanctions are likelier for a state
## outside the nuclear-weapon club of the Non-Proliferation Treaty).
## Rivals test too: a nuclear-armed state outside that club now and then when
## tension runs high, and a state that has just broken out, to prove it.

const Cbrn := preload("res://scripts/cbrn_data.gd")
const COST := {"money": 1500.0, "uranium": 30.0}
const DETERRENCE := 900.0
const COOLDOWN := 240.0
const KINDS := {
	"underground": {"name": "Underground test", "relations": 6.0, "tension": 8.0, "research": 250.0},
	"atmospheric": {"name": "Atmospheric test", "relations": 15.0, "tension": 15.0, "research": 400.0},
}

var w: Node
var deterred := {}      # nation -> until: its deterrent believed
var last := {}          # nation -> time of its last test
var count := {}         # nation -> tests made
var _ai_tick := 0.0

func _init(world: Node) -> void:
	w = world

## Why the player may not test, or "".
func blocked(kind: String) -> String:
	if not Cbrn.has(w, 0, "nuke"):
		return "Only a nuclear-armed nation can test."
	if w.get("wmd") != null and w.wmd != null and not w.wmd.armed(0, "nuclear"):
		return "A device is assembled at a Strategic Weapons Complex: build one first."
	if w.game_time - float(last.get(0, -1e9)) < COOLDOWN:
		return "The test site is being readied: %ds." % ceili(COOLDOWN - (w.game_time - float(last[0])))
	if _site(0) == Vector3.INF:
		return "No land of your own far enough from your towns."
	if not w.economy.can_afford(COST):
		return "A device costs %s." % w.hud.cost_text(COST)
	return ""

## The test site: your own land or the empty wilderness beyond it (no other
## nation's), as far as possible from your towns.
func _site(owner: int) -> Vector3:
	var towns: Array = w.buildings.filter(func(b): return int(b.owner) == owner and not b.dead and b.key in ["hq", "cityCenter", "villageCenter"])
	if towns.is_empty():
		return Vector3.INF
	var best := Vector3.INF
	var best_gap := 25.0   # at least this far from any town
	var t = w.territory
	for b in towns:
		for k in range(16):
			var p: Vector3 = b.root.position + Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0)) * randf_range(30.0, 110.0)
			if w.height_at(p.x, p.z) <= float(w.map.seaLevel) + 1.0:
				continue
			if t != null and t.has_method("owner_at") and not int(t.owner_at(p)) in [owner, -1]:
				continue   # never on another nation's land
			var gap := INF
			for c in towns:
				gap = minf(gap, c.root.position.distance_to(p))
			if gap > best_gap:
				best_gap = gap
				best = Vector3(p.x, w.height_at(p.x, p.z), p.z)
	return best

func conduct(owner: int, kind: String) -> String:
	if owner == 0:
		var why := blocked(kind)
		if why != "":
			return why
		w.economy.pay(COST)
	var at := _site(owner)
	if at == Vector3.INF:
		return ""
	var k: Dictionary = KINDS[kind]
	last[owner] = w.game_time
	count[owner] = int(count.get(owner, 0)) + 1
	deterred[owner] = w.game_time + DETERRENCE
	var d: Node = w.diplomacy
	# The blast.
	if kind == "atmospheric":
		w.effects.explosion(at + Vector3.UP * 2.0, 8.0, true)
		w.effects.mushroom(at, 30.0)
		if w.get("wmd") != null and w.wmd != null:
			w.wmd._zone("fallout", at, 28.0, 240.0, 0.8, owner, 0.35)
	else:
		w.effects.explosion(at, 3.0, true)
		w.effects.debris.scatter(at + Vector3.UP, 24, 8.0, 0.6, Color(0.36, 0.32, 0.26), 0.8)
	# What the world thinks of it.
	for i in range(d.n):
		if i != owner and not d.defeated(i):
			d.change(owner, i, -float(k.relations))
	d.changed.emit()
	if w.get("defcon") != null and w.defcon != null:
		w.defcon.tension = minf(79.0, w.defcon.tension + float(k.tension))
	if owner == 0 and w.research != null:
		w.research.add_points(float(k.research))
	var who: String = "You" if owner == 0 else d.name_of(owner)
	var text := "NUCLEAR TEST: %s %s a nuclear device %s. The world condemns it (relations -%d); for 15 minutes rivals believe the deterrent." % [
		who, "detonate" if owner == 0 else "detonates", "underground" if kind == "underground" else "in the open air, and its fallout drifts downwind", int(k.relations)]
	w.hud.notice(text)
	if w.get("un") != null and w.un != null:
		w.un.table("test", owner, -1, -1, "its %s nuclear test" % ("underground" if kind == "underground" else "atmospheric"))
	return text

## How strongly a rival is put off war with `owner` (diplomacy.ai_wants_war).
func believed(owner: int) -> bool:
	return float(deterred.get(owner, -1.0)) > w.game_time

func update(delta: float) -> void:
	_ai_tick += delta
	if _ai_tick < 60.0 or w.ai == null:
		return
	_ai_tick = 0.0
	var tension: float = w.defcon.tension if w.get("defcon") != null and w.defcon != null else 0.0
	for n in w.ai.nations:
		var owner: int = int(n.id)
		if n.defeated or not Cbrn.has(w, owner, "nuke") or w.game_time - float(last.get(owner, -1e9)) < 600.0:
			continue
		if w.get("wmd") != null and w.wmd != null and not w.wmd.armed(owner, "nuclear"):
			continue
		var outsider: bool = str(Cbrn.treaty(w, owner, "npt")) != "nws"
		var fresh: bool = w.get("wmd") != null and w.wmd != null and owner in w.wmd.broken_out and int(count.get(owner, 0)) == 0
		var chance := 0.0
		if fresh: chance = 0.5                        # a new nuclear state proves its bomb
		elif outsider and tension >= 25.0: chance = 0.03
		elif tension >= 60.0: chance = 0.005
		if randf() < chance:
			conduct(owner, "underground")

func capture() -> Dictionary:
	var out := {"deterred": {}, "last": {}, "count": {}}
	for k in deterred: out.deterred[str(k)] = deterred[k]
	for k in last: out.last[str(k)] = last[k]
	for k in count: out.count[str(k)] = count[k]
	return out

func restore(data: Dictionary) -> void:
	deterred.clear()
	last.clear()
	count.clear()
	for k in data.get("deterred", {}): deterred[int(k)] = float(data.deterred[k])
	for k in data.get("last", {}): last[int(k)] = float(data.last[k])
	for k in data.get("count", {}): count[int(k)] = int(data.count[k])
