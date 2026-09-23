extends Node
## Borders mean something. Armed forces may cross another nation's land only
## with its leave (a grant of passage), as its ally, or when the two are at
## war or in a limited operation. Anything else is a violation.
##
## Your orders: when you send forces into land you may not enter, the cabinet
## asks first: request passage (their government decides, by how it regards
## you), open a military operation (per the standing orders in the Diplomacy
## screen), cross anyway, or cancel.
##
## Trespass has consequences: relations sour while your forces stay, and a
## government that has put up with it long enough answers as it would any
## other incident (engagement.gd: a protest, a strike in kind, or war).
##
## Theirs: an AI force that enters your land uninvited brings a letter from
## your cabinet: grant passage, demand withdrawal (they pull back, relations
## cool), or open fire (a limited operation against them).
##
## A force with passage is a guest: it does not wear down the owner's hold on
## the land (territory.gd counts only hostile presence in foreign cells).

const GRANT := 240.0           ## seconds a grant of passage lasts
const PATIENCE := 25.0         ## seconds of trespass a government puts up with before it answers
const ANSWER_EVERY := 90.0     ## then at most one answer this often
const WATCH := 1.0

var world: Node
var grants := {}               ## "a>b" (a may cross b's land) -> match time the grant ends
var trespass := {}             ## "a>b" -> seconds of the current trespass
var answered := {}             ## "a>b" -> match time of the last government answer
var asked := {}                ## nation id -> match time the player was last asked about its forces
var incidents := {}            ## "a>b" -> border incidents so far (tests and the diplomacy screen)
var last_answers: Array = []   ## the answers of the latest border letter, for tests
var _tick := 0.0

func setup(world_node: Node) -> void:
	world = world_node

static func key(a: int, b: int) -> String:
	return "%d>%d" % [a, b]

func has_passage(a: int, b: int) -> bool:
	return world.diplomacy.allied(a, b) or float(grants.get(key(a, b), 0.0)) > world.game_time

func seconds_left(a: int, b: int) -> float:
	return maxf(float(grants.get(key(a, b), 0.0)) - world.game_time, 0.0)

## May `a`'s forces be in `b`'s land right now?
func free_to_cross(a: int, b: int) -> bool:
	if a == b or b < 0 or world.diplomacy.defeated(b):
		return true
	return world.hostile(a, b) or has_passage(a, b)

func grant(a: int, b: int, seconds := GRANT) -> void:
	grants[key(a, b)] = world.game_time + seconds
	trespass.erase(key(a, b))

## Would AI government `b` let `a` through? Friends yes, enemies no, and in
## between it depends on how warmly it regards `a`.
func will_grant(b: int, a: int) -> bool:
	var d: Node = world.diplomacy
	if d.allied(a, b):
		return true
	var warmth: float = d.rel(b, a) + (15.0 if d.pact[a][b] else 0.0) + (10.0 if d.nap[a][b] else 0.0)
	if warmth >= 50.0:
		return true  # a friend does not haggle
	return warmth >= 10.0 and randf() < clampf(0.35 + warmth / 80.0, 0.0, 0.95)

## The player asks nation `id` for passage. Returns what they said.
func request(id: int) -> String:
	if free_to_cross(0, id):
		return "Your forces may already cross %s." % world.diplomacy.name_of(id)
	if will_grant(id, 0):
		grant(0, id)
		return "%s grants your forces passage for %d minutes." % [world.diplomacy.name_of(id), int(GRANT / 60.0)]
	world.diplomacy.change(0, id, -2.0)
	return "%s refuses your forces passage." % world.diplomacy.name_of(id)

## Nations whose land the straight line from `from` to `to` crosses (and the
## land at `to`) that `a` may not enter.
func closed_land(a: int, from: Vector3, to: Vector3) -> Array[int]:
	var out: Array[int] = []
	var t: Node = world.territory
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var samples := maxi(1, ceili(length / 10.0))
	for k in range(1, samples + 1):
		var owner: int = t.owner_at(from.lerp(to, float(k) / samples))
		if owner >= 0 and not free_to_cross(a, owner) and not owner in out:
			out.append(owner)
	return out

## Called for the player's move orders before they are given. `issue` gives
## the order; it runs at once when no border is in the way.
func check_order(selected: Array, point: Vector3, issue: Callable) -> void:
	var soldiers: Array = selected.filter(func(u): return u.owner == 0 and not u.dead and u.dmg > 0.0 and not u.get("naval", false))
	if soldiers.is_empty() or world.territory == null:
		issue.call()
		return
	var centre := Vector3.ZERO
	for u in soldiers:
		centre += u.node.position
	centre /= soldiers.size()
	var closed := closed_land(0, centre, point)
	if closed.is_empty():
		issue.call()
		return
	var names := PackedStringArray()
	for id in closed:
		names.append(world.diplomacy.name_of(id))
	var doctrine: String = world.engagement.policy if world.engagement != null else "limited"
	last_answers = [
		["Request passage", "good", func():
			var refused := PackedStringArray()
			for id in closed:
				var said := request(id)
				world.hud.notice(said)
				if not has_passage(0, id):
					refused.append(world.diplomacy.name_of(id))
			if refused.is_empty():
				issue.call()
			else:
				world.hud.notice("Order held: no passage through %s." % ", ".join(refused))],
		["Military operation", "bad", func():
			for id in closed:
				world.engagement.begin(id, doctrine)
			issue.call()],
		["Cross anyway", "bad", func():
			issue.call()],
		["Cancel", "", func(): pass],
	]
	world.hud.choose("BORDER", "The route crosses land held by %s, and your forces have no right of passage.\n\nRequest passage, open a military operation (standing orders: %s), or cross without leave: a border incident that their government will answer." % [", ".join(names), "full war" if doctrine == "war" else "limited operation"], last_answers)

## Runs the named answer of the latest border letter (tests use this).
func answer(label: String) -> void:
	for a in last_answers:
		if a[0] == label:
			a[2].call()
			return

# ---------------------------------------------------------------- the watch

func _process(delta: float) -> void:
	if world == null or world.territory == null or world.game_over != "":
		return
	_tick += delta
	if _tick >= WATCH:
		_tick -= WATCH
		watch(WATCH)

## Who stands where they should not, and what follows.
func watch(seconds: float) -> void:
	var t: Node = world.territory
	var present := {}
	for u in world.units:
		if u.dead or u.dmg <= 0.0 or u.get("naval", false):
			continue
		var b: int = t.owner_at(u.node.position)
		if b < 0 or b == u.owner or free_to_cross(u.owner, b):
			continue
		var k := key(u.owner, b)
		present[k] = int(present.get(k, 0)) + 1
	for k in trespass.keys():
		if not present.has(k):
			trespass.erase(k)  # they left: the episode is over
	for k in present:
		var parts: PackedStringArray = k.split(">")
		var a := int(parts[0])
		var b := int(parts[1])
		var before: float = trespass.get(k, 0.0)
		trespass[k] = before + seconds
		if a == 0:
			_your_trespass(b, before, trespass[k])
		elif b == 0:
			_their_trespass(a, before)

func _your_trespass(b: int, before: float, now: float) -> void:
	var d: Node = world.diplomacy
	if before == 0.0:
		d.change(0, b, -3.0)
		world.hud.notice("Your forces have crossed into %s without leave. Relations -3." % d.name_of(b))
		incidents[key(0, b)] = int(incidents.get(key(0, b), 0)) + 1
	elif int(now) % 10 == 0:
		d.change(0, b, -1.5)
	if now >= PATIENCE and world.game_time - float(answered.get(key(0, b), -1000.0)) >= ANSWER_EVERY:
		answered[key(0, b)] = world.game_time
		if world.engagement != null:
			# The trespass is an incident like any strike: the government answers for itself.
			world.engagement.incidents[str(b)] = int(world.engagement.incidents.get(str(b), 0)) + 1
			world.engagement.answer(b)
	d.changed.emit()

func _their_trespass(a: int, before: float) -> void:
	if before > 0.0 or world.game_time - float(asked.get(a, -1000.0)) < 120.0:
		return
	asked[a] = world.game_time
	var d: Node = world.diplomacy
	d.change(0, a, -2.0)
	world.hud.choose("BORDER", "%s forces have crossed into your territory without leave." % d.name_of(a), [
		["Grant passage", "good", func():
			grant(a, 0)
			world.hud.notice("%s may cross your land for %d minutes." % [d.name_of(a), int(GRANT / 60.0)])],
		["Demand withdrawal", "", func():
			withdraw(a, 0)
			d.change(0, a, -3.0)
			world.hud.notice("%s pulls its forces back across the border." % d.name_of(a))],
		["Open fire", "bad", func():
			if world.engagement != null:
				world.engagement.begin(a, "limited")],
	])

## Sends `a`'s forces standing in `b`'s land back home.
func withdraw(a: int, b: int) -> void:
	var home = world.ai.hq(a) if world.ai != null else null
	if home == null:
		return
	var leaving: Array = world.units.filter(func(u): return u.owner == a and not u.dead and world.territory.owner_at(u.node.position) == b)
	if not leaving.is_empty():
		world.order_move(leaving, home.root.position)

# ---------------------------------------------------------------- saves

func capture() -> Dictionary:
	return {"grants": grants.duplicate(), "incidents": incidents.duplicate()}

func restore(data: Dictionary) -> void:
	grants = data.get("grants", {}).duplicate()
	incidents = data.get("incidents", {}).duplicate()
	trespass.clear()
	answered.clear()
