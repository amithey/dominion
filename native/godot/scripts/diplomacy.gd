extends Node
## Diplomacy between all nations, ported from js/diplomacy.js (core relations).
## Every pair has a relation score (-100..100) and treaty flags: war, alliance,
## trade pact and non-aggression pact. The player can declare war, offer
## peace, send a gift, and propose a trade pact, a non-aggression pact or an
## alliance, with the browser's thresholds and odds. Every 10 seconds: AI
## pairs drift, feud into war and sign ceasefires; peacetime relations with the
## player drift toward zero; trade pacts pay both sides $40. Declaring war
## ends every treaty between the two, and allies of the victim may join in.
## Foreign governments also write to the player with proposals to accept or
## decline.

signal changed

const TICK := 10.0
const GIFT := 250.0

var world: Node
var n := 0
var score := []
var war := []
var alliance := []
var pact := []
var nap := []
var aggression := 0.35
var _tick := 0.0
var _next_letter := 240.0      # no foreign mail in the first four minutes
var speed := 1.0

func setup(world_node: Node, nations: int, difficulty_aggression: float, time_speed := 1.0) -> void:
	world = world_node
	n = nations
	aggression = difficulty_aggression
	speed = time_speed
	_next_letter /= speed
	var grids := [score, war, alliance, pact, nap]
	for g in range(grids.size()):
		for a in range(n):
			var row := []
			row.resize(n)
			row.fill(0.0 if g == 0 else false)
			grids[g].append(row)
	for a in range(0, n):
		for b in range(a + 1, n):
			set_score(a, b, floorf((randf() - 0.4) * 50.0) if a > 0 else floorf((randf() - 0.5) * 30.0))

func name_of(id: int) -> String:
	return world.map.nations[id].name

func rel(a: int, b: int) -> float:
	return score[a][b]

func set_score(a: int, b: int, value: float) -> void:
	score[a][b] = clampf(value, -100.0, 100.0)
	score[b][a] = score[a][b]

func change(a: int, b: int, delta: float) -> void:
	set_score(a, b, rel(a, b) + delta)

func set_flag(grid: Array, a: int, b: int, value: bool) -> void:
	grid[a][b] = value
	grid[b][a] = value

func at_war(a: int, b: int) -> bool:
	return a != b and war[a][b]

func allied(a: int, b: int) -> bool:
	return a != b and alliance[a][b]

func defeated(id: int) -> bool:
	if id == 0 or world.ai == null:
		return false
	for nation in world.ai.nations:
		if nation.id == id:
			return nation.defeated
	return false

# ---------------------------------------------------------------- war and peace

func declare_war(a: int, b: int, reason := "") -> void:
	if a == b or war[a][b]:
		return
	var broke_nap: bool = nap[a][b]
	set_flag(war, a, b, true)
	for grid in [alliance, pact, nap]:
		set_flag(grid, a, b, false)
	set_score(a, b, -100.0)
	if a == 0 or b == 0:
		var other := b if a == 0 else a
		world.hud.notice(reason if reason != "" else ("You declared war on %s!" % name_of(other) if a == 0 else "%s has declared war on you!" % name_of(a)))
		if broke_nap and a == 0:
			world.hud.notice("You broke a non-aggression pact: every nation trusts you less.")
			for i in range(1, n):
				if i != other:
					change(0, i, -8.0)
		# Allies of whoever was attacked may join the war against the aggressor.
		for i in range(1, n):
			if i != a and i != b and allied(b, i) and not war[i][a] and not defeated(i) and randf() < 0.5:
				declare_war(i, a, "%s joins the war as an ally of %s!" % [name_of(i), "you" if b == 0 else name_of(b)])
	else:
		world.hud.notice("World news: %s declared war on %s." % [name_of(a), name_of(b)])
	changed.emit()

func make_peace(a: int, b: int) -> void:
	set_flag(war, a, b, false)
	set_score(a, b, -30.0 if a == 0 or b == 0 else -40.0)
	changed.emit()

func army_strength(id: int) -> int:
	return world.units.filter(func(u): return u.owner == id and not u.dead and u.dmg > 0.0).size()

## Player actions. Each returns the message shown to the player.
func offer_peace(other: int) -> String:
	if not at_war(0, other):
		return "You are not at war with %s." % name_of(other)
	var chance := clampf(0.35 + (army_strength(0) - army_strength(other)) * 0.04 + (1.0 - aggression) * 0.3, 0.05, 0.9)
	if randf() < chance:
		make_peace(0, other)
		return "%s accepted your peace offer. The guns fall silent." % name_of(other)
	return "%s rejected your peace offer. The war continues." % name_of(other)

func gift(other: int) -> String:
	if not world.economy.pay({"money": GIFT}):
		return "A meaningful gift costs $%d." % int(GIFT)
	var corps: bool = world.research != null and world.research.bonus("warmRelations") >= 1.0
	change(0, other, 18.0 if corps else 9.0)  # the Diplomatic Corps doubles a gift's effect
	changed.emit()
	return "Gift sent to %s. Relations improved." % name_of(other)

func propose_pact(other: int) -> String:
	if at_war(0, other):
		return "No trade during war."
	if rel(0, other) < 20.0:
		return "Relations too cold for a trade pact (+20 needed)."
	set_flag(pact, 0, other, true)
	change(0, other, 10.0)
	changed.emit()
	return "Trade pact signed with %s: $40 every 10 seconds for both sides." % name_of(other)

func propose_nap(other: int) -> String:
	if at_war(0, other):
		return "You cannot sign a non-aggression pact during war."
	if nap[0][other]:
		return "A non-aggression pact is already active."
	if rel(0, other) < 10.0:
		return "Relations need to be at least +10 for a non-aggression pact."
	if randf() < clampf(0.45 + rel(0, other) / 120.0, 0.25, 0.9):
		set_flag(nap, 0, other, true)
		change(0, other, 8.0)
		changed.emit()
		return "Non-aggression pact signed with %s. Neither side will start a war." % name_of(other)
	change(0, other, -3.0)
	return "%s refuses the non-aggression pact." % name_of(other)

func propose_alliance(other: int) -> String:
	if at_war(0, other):
		return "Make peace first."
	if rel(0, other) < 55.0:
		return "They need a relation of at least +55 to consider an alliance."
	if randf() < 0.75:
		set_flag(alliance, 0, other, true)
		change(0, other, 15.0)
		changed.emit()
		return "Alliance formed with %s! They may join your wars." % name_of(other)
	return "%s politely declined the alliance — for now." % name_of(other)

## Asks an ally to join the player's war against `target`.
func request_joint_war(ally: int, target: int) -> String:
	if not allied(0, ally) or not at_war(0, target) or at_war(ally, target):
		return ""
	if randf() < clampf(0.4 + rel(0, ally) / 200.0, 0.3, 0.85):
		declare_war(ally, target, "%s joins your war against %s!" % [name_of(ally), name_of(target)])
		return ""
	change(0, ally, -4.0)
	return "%s will not join this war." % name_of(ally)

# ---------------------------------------------------------------- AI decisions

## Whether AI nation `id` is willing to start a war with `other` now.
func ai_wants_war(id: int, other: int) -> bool:
	if at_war(id, other) or allied(id, other) or nap[id][other]:
		return false
	return rel(id, other) < -35.0 or (other == 0 and rel(id, 0) < 0.0 and randf() < aggression * 0.5)

## Enemies of AI nation `id`, player first.
func enemies_of(id: int) -> Array:
	var out := []
	for i in range(n):
		if at_war(id, i) and not defeated(i):
			out.append(i)
	return out

func _process(delta: float) -> void:
	if world == null or world.hud == null:
		return
	_tick += delta * speed
	if _tick >= TICK:
		_tick -= TICK
		tick()
	_next_letter -= delta
	if _next_letter <= 0.0:
		_next_letter = randf_range(150.0, 260.0) / speed
		write_letter()

func tick() -> void:
	for a in range(1, n):
		if defeated(a):
			continue
		for b in range(a + 1, n):
			if defeated(b):
				continue
			change(a, b, (randf() - 0.5) * 4.0)
			if not war[a][b] and rel(a, b) < -75.0 and not nap[a][b] and randf() < 0.05:
				declare_war(a, b)
			elif war[a][b] and randf() < 0.04:
				make_peace(a, b)
				world.hud.notice("World news: %s and %s signed a ceasefire." % [name_of(a), name_of(b)])
		# Peacetime relations with the player drift toward zero, but an
		# aggressive government (hard difficulty) keeps souring on its rival
		# unless treaties hold it back.
		if not war[0][a]:
			var drift := -0.3 if rel(0, a) > 0.0 else (1.2 if world.research and world.research.bonus("warmRelations") >= 1.0 else 0.5)
			if not (pact[0][a] or nap[0][a] or alliance[0][a]):
				drift -= aggression * 0.9
			change(0, a, drift)
		if pact[0][a]:
			world.economy.res.money += 40.0
			for nation in world.ai.nations:
				if nation.id == a:
					nation.money += 40.0
	changed.emit()

# A foreign government writes with a proposal that fits the relationship.
func write_letter() -> void:
	var candidates := range(1, n).filter(func(i): return not defeated(i))
	if candidates.is_empty():
		return
	var id: int = candidates[randi() % candidates.size()]
	var r := rel(0, id)
	if at_war(0, id):
		if army_strength(id) < army_strength(0) or randf() < 0.3:
			world.hud.ask("%s proposes a ceasefire." % name_of(id), _accept.bind("peace", id), _decline.bind(id, 5.0))
	elif r >= 55.0 and not allied(0, id):
		world.hud.ask("%s proposes an alliance." % name_of(id), _accept.bind("alliance", id), _decline.bind(id, 8.0))
	elif r >= 15.0 and not pact[0][id]:
		world.hud.ask("%s proposes a trade pact ($40 every 10 s for both)." % name_of(id), _accept.bind("pact", id), _decline.bind(id, 4.0))
	elif r < -20.0:
		world.hud.ask("%s demands $200 in tribute, or relations will suffer." % name_of(id), _accept.bind("tribute", id), _decline.bind(id, 15.0))
	elif not nap[0][id]:
		world.hud.ask("%s asks for a non-aggression pact." % name_of(id), _accept.bind("nap", id), _decline.bind(id, 3.0))

func _accept(kind: String, id: int) -> void:
	match kind:
		"peace":
			make_peace(0, id)
			world.hud.notice("Ceasefire with %s." % name_of(id))
		"alliance":
			set_flag(alliance, 0, id, true)
			change(0, id, 15.0)
		"pact":
			set_flag(pact, 0, id, true)
			change(0, id, 10.0)
		"nap":
			set_flag(nap, 0, id, true)
			change(0, id, 8.0)
		"tribute":
			if world.economy.pay({"money": 200.0}):
				change(0, id, 12.0)
			else:
				change(0, id, -15.0)
				world.hud.notice("You cannot pay: %s is offended." % name_of(id))
	changed.emit()

func _decline(id: int, cost: float) -> void:
	change(0, id, -cost)
	changed.emit()

# ---------------------------------------------------------------- panel text

func status_text(other: int) -> String:
	if defeated(other):
		return "defeated"
	var parts := []
	if at_war(0, other):
		parts.append("AT WAR")
	if allied(0, other):
		parts.append("ally")
	if pact[0][other]:
		parts.append("trade pact")
	if nap[0][other]:
		parts.append("non-aggression")
	if parts.is_empty():
		parts.append("peace")
	return ", ".join(PackedStringArray(parts))
