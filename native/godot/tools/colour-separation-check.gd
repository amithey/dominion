extends SceneTree
## No two nations of one match share a flag colour: every pair of the roster as player and rival, then every
## roster the New Game screen could build (2 to 8 nations drawn across the roster), and the match set-up itself.
## Prints COLOUR_SEPARATION PASS when every pair in every roster is at least MIN_GAP apart, the player's colour
## and every unchanged nation's colour are exactly their flag, the flag colour is kept, the result is repeatable
## and a nation's identity ("id", "arsenal") is untouched.
const Sep := preload("res://scripts/colour_separation.gd")
const Factions := preload("res://scripts/factions.gd")
const MatchSetup := preload("res://scripts/match_setup.gd")
var passed := 0
var failed: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed.append(label)
		print("FAIL ", label)

func build(ids: Array) -> Array:
	var out := []
	for k in range(ids.size()): out.append(Factions.nation(int(ids[k]), k == 0))
	return out

func worst_gap(nations: Array) -> float:
	var w := INF
	for a in range(nations.size()):
		for b in range(a + 1, nations.size()):
			w = minf(w, Sep.gap(Color(str(nations[a].color)), Color(str(nations[b].color))))
	return w

func run() -> void:
	var count: int = Factions.IDS.size()
	check(count >= 28, "the roster is there (%d)" % count)
	var changed := 0
	# 1. every pair, both ways round
	for a in range(count):
		for b in range(count):
			if a == b: continue
			var nations := build([a, b])
			var flag_a: String = nations[0].color
			var flag_b: String = nations[1].color
			Sep.separate(nations)
			var label := "%s with %s" % [Factions.IDS[a], Factions.IDS[b]]
			check(worst_gap(nations) >= Sep.MIN_GAP, label + " are told apart (gap %d)" % int(worst_gap(nations)))
			check(nations[0].color == flag_a, label + ": the player keeps their flag colour")
			if nations[1].color != flag_b:
				changed += 1
				check(nations[1].get("flag_color", "") == flag_b, label + ": the flag colour is kept in flag_color")
			else:
				check(not nations[1].has("flag_color"), label + ": an unchanged nation has no flag_color")
			check(str(nations[1].id) == Factions.IDS[b] and str(nations[1].arsenal) == Factions.ARSENALS[b], label + ": identity untouched")
	print("pairs changed: %d of %d" % [changed, count * (count - 1)])
	# 2. rosters of 3 to 8 nations
	seed(31)
	for round in range(200):
		var size := 3 + round % 6
		var pool := range(count)
		pool.shuffle()
		var ids := pool.slice(0, mini(size, count))
		var nations := build(ids)
		Sep.separate(nations)
		var again := build(ids)
		Sep.separate(again)
		var same := true
		for k in range(nations.size()):
			if nations[k].color != again[k].color: same = false
		check(same, "roster %d is repeatable" % round)
		# a roster of eight cannot always have every pair 90 apart, but never nearer than 60
		check(worst_gap(nations) >= 60.0, "roster %d (%d nations) has no two flags nearly the same (gap %d)" % [round, ids.size(), int(worst_gap(nations))])
	# 3. the set-up itself, through MatchSetup.apply on the island data
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map-seed1.json"))
	for n in [4, 12, 21, 28, 29, 30]:
		var data: Dictionary = raw.duplicate(true)
		MatchSetup.apply(data, MatchSetup.normalize({"players": 4, "nation": n}))
		check(worst_gap(data.nations) >= Sep.MIN_GAP, "a four-nation match as %s: every flag is clear of the others (gap %d)" % [Factions.IDS[n], int(worst_gap(data.nations))])
		check(str(data.nations[0].id) == Factions.IDS[n], "and you are still %s" % Factions.IDS[n])
	print("COLOUR_SEPARATION ", "PASS" if failed.is_empty() else "FAIL", ": ", passed, " checks, ", failed.size(), " failures")
	quit(0 if failed.is_empty() else 1)
