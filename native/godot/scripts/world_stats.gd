extends RefCounted
## National statistics over time, as statistics offices, the IMF, SIPRI and the Fragile States Index
## publish them (native/STATISTICS-2026-10-18.md, native/CRISES-2026-10-20.md): the economy (GDP, its
## growth, inflation, unemployment, public debt), security (military strength, defence spending), society
## (fragility, people displaced, energy) and the nation (land, technology, infrastructure), sampled as the
## match runs and drawn as charts.
##
## GDP is what stands: the nation's real-world economy scaled by its standing, working economic buildings
## against a normal size (crisis.gd development), times how hard they work (blackouts, inflation, default,
## turmoil, war, sanctions). A nation whose industry lies in ruins publishes a collapse.
##
## What you see of the others is what is published, not the truth:
##   economic figures, fragility,      public figures, a release late (GDP a little rounded)
##   land, technology, the displaced
##   defence spending                  a published estimate: half the error of the military's
##   military strength                 an estimate; the better your intelligence on that nation, the closer
##                                     (35% off with none, 5% with a full network)
##   infrastructure, energy            satellite and trade-press estimates (as the military's)
## Your own figures are exact. The estimate's error for one nation does not jitter from chart to chart: it is
## a fixed draw per nation and release, scaled by how much you know.

const SAMPLE := 20.0              # game seconds between releases
const MAX_SAMPLES := 400
const METRICS := ["gdp", "growth", "inflation", "unemployment", "debt", "rating", "military", "milex", "fragility", "displaced", "energy", "land", "tech", "infra"]
const GROUPS := [["Economy", ["gdp", "growth", "inflation", "unemployment", "debt", "rating"]], ["Security", ["military", "milex"]],
	["Society", ["fragility", "displaced", "energy"]], ["Nation", ["land", "tech", "infra"]]]
const TITLES := {"gdp": "GDP", "growth": "Growth", "inflation": "Inflation", "unemployment": "Unemployment", "debt": "Public debt", "rating": "Credit rating",
	"military": "Military", "milex": "Defence spending", "fragility": "Fragility", "displaced": "Displaced", "energy": "Energy",
	"land": "Land", "tech": "Technology", "infra": "Infrastructure"}
const UNITS := {"gdp": "$ bn", "growth": "% over a quarter", "inflation": "% a year", "unemployment": "% of workers", "debt": "% of GDP", "rating": "score, 0 to 100",
	"military": "points", "milex": "% of GDP", "fragility": "index, 0 to 120", "displaced": "thousand people", "energy": "GW",
	"land": "hexes", "tech": "level", "infra": "buildings"}
const NOTES := {
	"gdp": "Gross domestic product: the economy that stands and works. A nation starts below its real-world figure and reaches it as its economy is built up; destroyed industry, blackouts, inflation, default and turmoil bring it down. A public figure released with a delay.",
	"growth": "The change in GDP over the last quarter (three minutes). Two quarters of decline are a recession.",
	"inflation": "Consumer prices, a year on year. Lost supply, blackouts, hunger, war spending, sanctions and default push it up; past about 30% the currency is in crisis.",
	"unemployment": "The share of workers without a job: workplaces destroyed, factories without power, people without homes.",
	"debt": "General government gross debt. War deficits add to it and a shrinking economy raises it at once; too high and the state defaults.",
	"rating": "What the markets make of the state: debt, inflation, fragility, losses and war, as a score from 0 to 100 (AAA at 85 and above, D at the bottom). A published figure, a release late.",
	"military": "The value of the forces under arms. For other nations an estimate: the better your intelligence, the closer.",
	"milex": "Military expenditure as a share of GDP, as the peace research institutes publish it: higher at war and in a shrinking economy. Others' figures are estimates.",
	"fragility": "How close the state is to failing, on the scale of the Fragile States Index (higher is worse): its usual level plus the pressure of its crises. Past the pressure a government can bear, it falls.",
	"displaced": "People driven from their homes by destroyed houses and towns, as the refugee agency counts them; they find shelter over time.",
	"energy": "Generating and fuel capacity: power stations, reactors, solar farms, refineries, rigs and wells. Others' figures are estimated from satellites (night lights).",
	"land": "Hexes of territory held; borders are public.",
	"tech": "Technology level (0 to 10); scientific output is public.",
	"infra": "Finished buildings. For other nations an estimate from satellites and trade papers.",
}
const ESTIMATED := ["military", "infra", "energy", "milex"]
const QUARTER := 180.0
const GROWTH_FLOOR := 0.5          # growth is measured against at least this share of the real economy
## Real-world output used as each nation's starting economy, in billions of dollars (round figures).
const BASE_GDP := {"usa": 29000, "china": 18700, "germany": 4900, "france": 3400, "italy": 2400, "netherlands": 1350, "iran": 400, "russia": 2200, "india": 3900, "japan": 4000, "turkiye": 1300, "israel": 530,
	"uk": 3600, "south_korea": 1870, "saudi": 1100, "brazil": 2200, "indonesia": 1400, "ukraine": 190, "north_korea": 25, "egypt": 350, "australia": 1800,
	"pakistan": 370, "iraq": 270, "syria": 12, "afghanistan": 17, "yemen": 20, "houthis": 4, "ethiopia": 150, "nigeria": 190, "south_sudan": 5, "sudan": 30}
const CIVIC_WEIGHT := 0.6          # a civic building adds this much of an economic one to output
const HEADLINE_EVERY := 120.0      # at most one headline in this many seconds
const HEADLINE_MOVE := 0.12        # a published figure moved by this share since two minutes ago

var w: Node
var series := {}                   # nation -> metric -> Array of {t, real, shown}
var crisis_shown := {}             # nation -> the crises it was in at the previous release (what is published)
var _crisis_truth := {}            # nation -> the crises it is in now
var _clock := 0.0
var _samples := 0
var _base_output := {}             # nation -> output at the first release (the index's denominator)
var _last_headline := -999.0
var headlines := 0                 # (tests)

func _init(world: Node) -> void:
	w = world

## Every frame (world._physics_process, the economy block): a release every SAMPLE seconds.
func update(delta: float) -> void:
	_clock += delta
	if _clock < SAMPLE and _samples > 0:
		return
	_clock = 0.0
	release()

## One release: every nation's figures now.
func release() -> void:
	_samples += 1
	var now := float(w.game_time)
	for id in range(w.map.nations.size()):
		var truth := _truth(id)
		if truth.is_empty():
			continue
		if not series.has(id):
			series[id] = {}
		for m in METRICS:
			if not series[id].has(m):
				series[id][m] = []   # (a save from before the metric)
		var real_size: float = float(BASE_GDP.get(preload("res://scripts/factions.gd").identity(w, id), 500)) * GROWTH_FLOOR
		truth.growth = _growth(series[id].gdp, now, float(truth.gdp), "real", 0, real_size)
		for m in METRICS:
			var list: Array = series[id][m]
			var shown := _shown(id, m, float(truth[m]), list)
			if m == "growth" and id != 0:
				shown = _growth(series[id].gdp, now, float(series[id].gdp[series[id].gdp.size() - 1].shown) if not series[id].gdp.is_empty() else float(truth.gdp), "shown", 1, real_size)
			list.append({"t": now, "real": float(truth[m]), "shown": shown})
			if list.size() > MAX_SAMPLES:
				list.pop_front()
	for id in range(w.map.nations.size()):
		var now_list: Array = w.crisis.list(id) if w.get("crisis") != null and w.crisis != null else []
		crisis_shown[id] = now_list if id == 0 else _crisis_truth.get(id, [])   # (yours exact, the others a release late)
		_crisis_truth[id] = now_list
	_headline()

## The crises of `id` as published (yours now; a rival's at the last release).
func crises(id: int) -> Array:
	if id == 0:
		return w.crisis.list(0) if w.get("crisis") != null and w.crisis != null else []
	return crisis_shown.get(id, [])

## GDP growth (%) over the last quarter: from the gdp `list` (field `field`, the newest `skip` entries
## excluded: the published figure is a release late) to `value`. A young economy is measured against at
## least `floor_at` (a share of its real size), so building the first factories is not a thousandfold boom.
func _growth(list: Array, now: float, value: float, field: String, skip := 0, floor_at := 0.0) -> float:
	var then := -1.0
	for i in range(list.size() - 1 - skip, -1, -1):
		if now - float(list[i].t) >= QUARTER:
			then = float(list[i][field])
			break
	if then <= 0.0:
		return 0.0
	return (value - then) / maxf(then, floor_at) * 100.0

## The true figures of nation `id` (empty for one that does not exist).
func _truth(id: int) -> Dictionary:
	var d: Node = w.diplomacy
	if id >= w.map.nations.size() or (d != null and id > 0 and d.defeated(id)):
		return {}
	var output := 0.0
	var built := 0
	var force := 0.0
	for b in w.buildings:
		if b.owner != id or b.dead or not b.built:
			continue
		built += 1
		var cat: String = str(b.def.get("cat", ""))
		if cat == "military":
			continue
		var value: float = float(b.def.get("cost", {}).get("money", 100.0)) / 100.0
		output += value * (CIVIC_WEIGHT if cat == "civic" else 1.0)
	for u in w.units:
		if u.owner != id or u.dead or u.get("stowed", false) or float(u.get("dmg", 0)) <= 0.0:
			continue
		var cost: Dictionary = w.unit_defs.get(u.key, {}).get("cost", {})
		var price := 0.0
		for r in cost:
			price += float(cost[r]) * (1.0 if r == "money" else (3.0 if r in ["iron", "oil"] else 5.0))
		force += price * clampf(float(u.hp) / maxf(float(u.max_hp), 1.0), 0.2, 1.0) / 100.0
	var base: float = float(BASE_GDP.get(preload("res://scripts/factions.gd").identity(w, id), 500))
	var land := 0
	if w.territory != null:
		for o in w.territory.owner_of:
			if o == id: land += 1
	var out := {"military": force, "land": float(land), "tech": _tech(id), "infra": float(built), "growth": 0.0}
	var c: RefCounted = w.get("crisis")
	if c != null:
		var s: Dictionary = c.of(id)
		if not s.get("seen", false):
			c.step(0.0)   # (the first release comes before the first measure)
		out.gdp = base * c.development(id) * c.activity(id)
		out.inflation = float(s.inflation)
		out.unemployment = float(s.unemployment)
		out.debt = float(s.debt)
		out.milex = float(s.milex)
		out.fragility = c.fragility(id)
		out.rating = c.rating_score(id)
		out.displaced = float(s.displaced)
		out.energy = float(s.energy) * 0.2
	else:
		out.gdp = base * (output + 2.0) / 45.0
		for m in ["inflation", "unemployment", "debt", "milex", "fragility", "displaced", "energy", "rating"]:
			out[m] = 0.0
	return out

func _tech(id: int) -> float:
	if id == 0:
		var total := maxi(w.research.discoveries.size(), 1)
		return 10.0 * float(w.research.completed_count()) / total
	if w.ai == null:
		return 0.0
	for n in w.ai.nations:
		if n.id == id:
			return float(n.get("tech", 0.0))
	return 0.0

## What the player is shown for `id`'s metric: exact for oneself, public or estimated for others.
func _shown(id: int, metric: String, truth: float, list: Array) -> float:
	if id == 0:
		return truth
	match metric:
		"land", "tech", "inflation", "unemployment", "debt", "fragility", "rating":
			return list[list.size() - 1].real if not list.is_empty() else truth   # a release late
		"displaced":
			var late: float = list[list.size() - 1].real if not list.is_empty() else truth
			return roundf(late)
		"milex":
			return maxf(0.0, truth * (1.0 + error(id) * 0.5 * _noise(id, metric, _samples)))
		"gdp":
			var lagged: float = list[list.size() - 1].real if not list.is_empty() else truth
			return roundf(lagged / 10.0) * 10.0 if lagged >= 200.0 else roundf(lagged)
		_:
			return maxf(0.0, truth * (1.0 + error(id) * _noise(id, metric, _samples)))

## The estimate's fractional error bound for `id` (military and infrastructure), from what you know of it.
func error(id: int) -> float:
	var level := 0.0
	if w.espionage != null:
		level = clampf(float(w.espionage.intel.get(id, 0.0)) / 100.0, 0.0, 1.0)
	return lerpf(0.35, 0.05, level)

## A fixed draw in [-1, 1] for (nation, metric, release): the same every time it is asked.
func _noise(id: int, metric: String, release_no: int) -> float:
	var h: int = hash([id, metric, release_no / 3])   # the same for three releases in a row: a real estimate drifts slowly
	return float(absi(h) % 2001) / 1000.0 - 1.0

# ---------------------------------------------------------------- reading

## The shown series of `metric` for nation `id`: [{t, v}], oldest first.
func points(id: int, metric: String) -> Array:
	var out := []
	for s in series.get(id, {}).get(metric, []):
		out.append({"t": s.t, "v": s.shown})
	return out

## The latest shown value of `metric` for `id`.
func latest(id: int, metric: String) -> float:
	var list: Array = series.get(id, {}).get(metric, [])
	return float(list[list.size() - 1].shown) if not list.is_empty() else 0.0

## The change of the shown figure over the last `seconds`, as a fraction (0.12 = up 12%).
func change(id: int, metric: String, seconds := 120.0) -> float:
	var list: Array = series.get(id, {}).get(metric, [])
	if list.size() < 2:
		return 0.0
	var last: Dictionary = list[list.size() - 1]
	var then: Dictionary = list[0]
	for i in range(list.size() - 1, -1, -1):
		if float(last.t) - float(list[i].t) >= seconds:
			then = list[i]
			break
	return (float(last.shown) - float(then.shown)) / maxf(absf(float(then.shown)), 0.0001)

## Nations ranked by the shown figure, highest first: [[id, value], ...].
func ranking(metric: String) -> Array:
	var out := []
	for id in series:
		out.append([id, latest(id, metric)])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out

## Formats a figure for the metric.
static func format(metric: String, v: float) -> String:
	match metric:
		"gdp":
			return ("$%.1f tn" % (v / 1000.0)) if v >= 10000.0 else ("$%d bn" % int(roundf(v)))
		"growth":
			return "%+.1f%%" % v
		"inflation", "unemployment", "milex":
			return "%.1f%%" % v
		"debt":
			return "%d%%" % int(roundf(v))
		"rating":
			return preload("res://scripts/crisis.gd").rating_letters(v)
		"fragility", "energy":
			return "%.1f" % v
		"displaced":
			return "%dk" % int(roundf(v))
		"tech":
			return "%.1f" % v
		_:
			return str(int(roundf(v)))

## A headline when a published figure of another nation has moved much.
func _headline() -> void:
	var now := float(w.game_time)
	if w.hud == null or now - _last_headline < HEADLINE_EVERY or now < 240.0:
		return
	var best_id := -1
	var best_metric := ""
	var best := 0.0
	for id in series:
		if id == 0:
			continue
		for m in ["gdp", "military", "land"]:
			var c := change(id, m, 120.0)
			if absf(c) >= HEADLINE_MOVE and absf(c) > best:
				best = absf(c)
				best_id = id
				best_metric = m
	if best_id < 0:
		return
	_last_headline = now
	headlines += 1
	var c := change(best_id, best_metric, 120.0)
	var noun: String = {"gdp": "output", "military": "forces", "land": "territory"}[best_metric]
	var name: String = w.diplomacy.name_of(best_id)
	var text := "Statistics: %s's %s %s %d%% in the last two minutes." % [name, noun, "rose" if c > 0.0 else "fell", int(roundf(absf(c) * 100.0))]
	if best_metric == "military":
		text += " (An estimate: %d%% either way.)" % int(roundf(error(best_id) * 100.0))
	w.hud.notice(text)

# ---------------------------------------------------------------- saves

func capture() -> Dictionary:
	var out := {}
	for id in series:
		out[str(id)] = series[id].duplicate(true)
	return {"series": out, "base": _base_output.duplicate(), "samples": _samples, "clock": _clock, "headline": _last_headline,
		"crises": {"shown": crisis_shown.duplicate(true), "truth": _crisis_truth.duplicate(true)}}

func restore(data: Dictionary) -> void:
	series = {}
	for key in data.get("series", {}):
		series[int(key)] = {}
		for m in data.series[key]:
			series[int(key)][m] = []
			for s in data.series[key][m]:
				series[int(key)][m].append({"t": float(s.t), "real": float(s.real), "shown": float(s.shown)})
	_base_output = {}
	for key in data.get("base", {}):
		_base_output[int(key)] = float(data.base[key])
	_samples = int(data.get("samples", 0))
	_clock = float(data.get("clock", 0.0))
	_last_headline = float(data.get("headline", -999.0))
	crisis_shown = {}
	_crisis_truth = {}
	for key in data.get("crises", {}).get("shown", {}):
		crisis_shown[int(key)] = data.crises.shown[key]
	for key in data.get("crises", {}).get("truth", {}):
		_crisis_truth[int(key)] = data.crises.truth[key]
