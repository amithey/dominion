extends RefCounted
## National crises: what the loss of a nation's buildings and infrastructure does to its economy, its
## politics and its standing in the world (native/CRISES-2026-10-20.md).
##
## Every nation, you and the rivals alike, is measured every two seconds:
##   output      what its standing economy produces (homes, farms, industry, energy, trade, civic
##               buildings, each by its cost and its damage), against the peak it reached lately
##   energy      its power stations, reactors, solar farms, refineries, rigs and oil and gas wells
##   food        its farms, wharves, platforms and food depots
##   displaced   people driven from homes and towns that were destroyed
## and from these, as an economist would, its inflation, unemployment, public debt, defence spending
## and an index of how fragile the state has become. Losses past a threshold are a CRISIS:
##   economic      recession, depression, energy crisis (blackouts), food crisis, currency crisis,
##                 sovereign default
##   political     a political crisis (mass protest); past it the government falls (a democracy or
##                 a hybrid regime signs a ceasefire) or cracks down (an autocracy)
##   humanitarian  displacement
##   diplomatic    a nation whose strikes destroy another's homes, power and hospitals is condemned:
##                 the nations not at war with it think less of it
## Each crisis costs income, production and happiness (yours through research bonuses, a rival's
## through its income) and lowers the people's support for the war (war_support.gd). It ends with
## hysteresis when the cause is repaired, rebuilt or simply lived with: the "peak" an economy is
## measured against settles toward what stands over some six minutes.

const Factions := preload("res://scripts/factions.gd")
const FactionPowers := preload("res://scripts/faction_powers.gd")

const STEP := 2.0
const ADAPT := 360.0              # seconds for the measure of "normal" to settle on what is left
const NORMAL_OUTPUT := 45.0       # output at which a nation's economy is its real-world size (world_stats.gd)
const CAPITAL_OUTPUT := 4.0       # the capital's own ministries, banks, shops and streets
const YEAR := 720.0               # four seasons of 180 seconds
const CONDEMN_AT := 6.0
const CONDEMN_DECAY := 1.0 / 60.0

const ENERGY := ["powerPlant", "nuclearReactor", "solarFarm", "oilRefinery", "offshoreRig"]
const FOOD := ["farm", "fishingWharf", "fishingPlatform", "foodDepot"]
const TOWN_PEOPLE := {"hq": 200.0, "cityCenter": 260.0, "villageCenter": 90.0}   # (economy.POPULATION_WEIGHTS)
const CIVILIAN := ["hospital", "school", "university", "library", "waterTreatment", "museum", "park", "stadium"]

## Round real-world baselines of each nation (see the doc for the sources): consumer-price inflation (%),
## unemployment (%), general government gross debt (% of GDP), military spending (% of GDP) and the
## Fragile States Index (0 to 120; higher is more fragile).
const BASE := {
	"usa":         [3.0, 4.2, 121.0, 3.4, 46.0],
	"china":       [0.5, 5.1, 88.0, 1.7, 69.0],
	"germany":     [2.2, 3.8, 63.0, 2.4, 27.0],
	"france":      [1.2, 7.6, 116.0, 2.0, 33.0],
	"italy":       [1.5, 6.1, 137.0, 2.0, 34.0],
	"iran":        [35.0, 8.5, 34.0, 2.0, 83.0],
	"russia":      [8.5, 2.5, 20.0, 7.1, 74.0],
	"india":       [4.5, 4.9, 83.0, 2.3, 75.0],
	"japan":       [2.7, 2.5, 235.0, 1.4, 32.0],
	"turkiye":     [45.0, 8.7, 25.0, 2.1, 80.0],
	"israel":      [3.0, 3.0, 68.0, 8.8, 76.0],
	"uk":          [3.0, 4.4, 101.0, 2.3, 41.0],
	"south_korea": [2.3, 2.8, 52.0, 2.6, 32.0],
	"saudi":       [2.0, 4.0, 29.0, 7.3, 65.0],
	"brazil":      [5.0, 6.6, 88.0, 1.1, 70.0],
	"indonesia":   [2.0, 4.8, 40.0, 0.7, 64.0],
	"ukraine":     [10.0, 12.0, 92.0, 34.0, 87.0],
	"north_korea": [5.0, 3.0, 30.0, 24.0, 90.0],
	"egypt":       [25.0, 6.8, 90.0, 1.2, 84.0],
	"australia":   [3.0, 4.1, 50.0, 2.0, 20.0],
	"pakistan":    [12.0, 7.0, 70.0, 2.7, 89.0],
	"iraq":        [3.5, 15.0, 45.0, 3.0, 93.0],
	"syria":       [50.0, 25.0, 100.0, 4.0, 107.0],
	"afghanistan": [5.0, 15.0, 10.0, 1.0, 102.0],
	"yemen":       [20.0, 18.0, 80.0, 5.0, 111.0],
	"houthis":     [25.0, 25.0, 50.0, 20.0, 111.0],
	"ethiopia":    [25.0, 4.0, 40.0, 1.7, 98.0],
	"nigeria":     [28.0, 5.0, 45.0, 0.6, 98.0],
	"south_sudan": [60.0, 12.0, 60.0, 3.0, 109.0],
	"sudan":       [120.0, 20.0, 250.0, 5.0, 109.0],
}
const DEFAULT_BASE := [5.0, 6.0, 60.0, 2.0, 70.0]

## The crises: who they are for, what sets them off (in step()), what they do.
##   player   research bonuses while it lasts (research._recompute)
##   ai       a rival's income multiplier
##   drain    war support lost a second (times the regime's sensitivity)
##   public   reported in the world's news when it strikes a rival (all are in the statistics)
const KINDS := {
	"recession":    {"title": "Recession", "group": "economic", "player": {"incomePct": -0.06, "happiness": -3.0}, "ai": 0.94, "drain": 0.0, "public": false,
		"text": "Output has fallen by more than a sixth from its level: income -6%, happiness -3."},
	"depression":   {"title": "Depression", "group": "economic", "player": {"incomePct": -0.15, "prodPct": -0.05, "happiness": -6.0}, "ai": 0.85, "drain": 0.02, "public": true,
		"text": "Output has fallen by two fifths: income -15%, production -5%, happiness -6."},
	"energy":       {"title": "Energy crisis", "group": "economic", "player": {"incomePct": -0.05, "prodPct": -0.15, "researchPct": -0.1, "happiness": -4.0}, "ai": 0.9, "drain": 0.01, "public": true,
		"text": "The power stations are down: rolling blackouts. Production -15%, research -10%, income -5%, happiness -4."},
	"food":         {"title": "Food crisis", "group": "economic", "player": {"happiness": -5.0, "health": -4.0}, "ai": 0.96, "drain": 0.01, "public": false,
		"text": "Half the farms and fisheries are gone: food prices soar. Happiness -5, health -4."},
	"currency":     {"title": "Currency crisis", "group": "economic", "player": {"incomePct": -0.08, "happiness": -3.0}, "ai": 0.92, "drain": 0.01, "public": true,
		"text": "Inflation is out of control and the currency falls: income -8%, happiness -3."},
	"default":      {"title": "Sovereign default", "group": "economic", "player": {"incomePct": -0.12}, "ai": 0.88, "drain": 0.01, "public": true,
		"text": "The state cannot pay its debts and no one will lend: income -12% until the books recover."},
	"humanitarian": {"title": "Displacement", "group": "humanitarian", "player": {"happiness": -4.0, "incomePct": -0.03}, "ai": 0.97, "drain": 0.01, "public": true,
		"text": "A large share of the people have lost their homes: happiness -4, income -3%."},
	"political":    {"title": "Political crisis", "group": "political", "player": {"incomePct": -0.06, "prodPct": -0.05, "happiness": -3.0}, "ai": 0.93, "drain": 0.04, "public": true,
		"text": "Mass protests against the government: income -6%, production -5%, and support for the war drains. If the pressure keeps rising, the government will fall."},
	"collapse":     {"title": "Government collapse", "group": "political", "player": {"incomePct": -0.12, "prodPct": -0.1, "happiness": -5.0}, "ai": 0.85, "drain": 0.0, "public": true,
		"text": "The government has fallen: income -12%, production -10% for three minutes."},
	"isolation":    {"title": "International condemnation", "group": "diplomatic", "player": {"incomePct": -0.04}, "ai": 0.96, "drain": 0.01, "public": true,
		"text": "The world condemns strikes on homes, power stations and hospitals: the nations not at war with the striker think less of it, and its trade suffers (income -4%)."},
}
const HOLD := 6.0                 # a crisis begins only when its cause has held this long (not a building being replaced)
const SMALL := 20.0               # an economy smaller than this is measured as if it were this size (a young nation is not
                                  # thrown into depression by one lost farm)
const PROTEST_BEFORE_FALL := 90.0 # the protests last this long before a government can fall
const AFTERMATH := 180.0          # how long a fallen government's turmoil lasts
const FALL_AGAIN := 300.0         # and the least time before another

var w: Node
var state := {}                    # nation -> Dictionary (see _fresh)
var notices := 0                   # (tests) crisis messages given
var _clock := 0.0
var _player_kinds := ""            # the player's active crises, to know when to recompute bonuses
var _last_news := -999.0           # a rival's crisis in the news at most every NEWS_GAP seconds
const NEWS_GAP := 40.0

func _init(world: Node) -> void:
	w = world

func _fresh(id: int) -> Dictionary:
	var b: Array = base_of(id)
	return {"out": 0.0, "peak": 0.0, "energy": 0.0, "energy_peak": 0.0, "food": 0.0, "food_peak": 0.0, "homes": 0.0,
		"displaced": 0.0, "inflation": float(b[0]), "unemployment": float(b[1]), "debt": float(b[2]), "milex": float(b[3]),
		"pressure": 0.0, "condemn": 0.0, "crises": {}, "pending": {}, "fell_at": -9999.0, "g_prev": -1.0, "score0": -1.0, "seen": false}

func base_of(id: int) -> Array:
	return BASE.get(Factions.identity(w, id), DEFAULT_BASE)

func of(id: int) -> Dictionary:
	if not state.has(id):
		state[id] = _fresh(id)
	return state[id]

func active(id: int, kind: String) -> bool:
	return of(id).crises.has(kind)

## The crises of `id` in force, in the order of KINDS.
func list(id: int) -> Array:
	var out := []
	for k in KINDS:
		if active(id, k):
			out.append(k)
	return out

# ---------------------------------------------------------------- measuring

func update(delta: float) -> void:
	_clock += delta
	if _clock < STEP:
		return
	step(_clock)
	_clock = 0.0

## What stands, per nation: output, energy, food and housing (built buildings, by cost and health).
func _measure() -> Dictionary:
	var m := {}
	for b in w.buildings:
		if b.dead or not b.built:
			continue
		var id: int = int(b.owner)
		if id < 0:
			continue
		if not m.has(id):
			m[id] = {"out": 0.0, "energy": 0.0, "food": 0.0, "homes": 0.0}
		var row: Dictionary = m[id]
		var health := clampf(float(b.hp) / maxf(float(b.get("max_hp", 1.0)), 1.0), 0.25, 1.0)
		var value: float = float(b.def.get("cost", {}).get("money", 100.0)) / 100.0 * health
		var cat := str(b.def.get("cat", ""))
		if b.key == "hq":
			row.out += CAPITAL_OUTPUT * health
		elif cat != "military":
			row.out += value * (0.6 if cat == "civic" else 1.0)
		if b.key in ENERGY or (b.key == "extractor" and b.get("deposit") != null and str(b.deposit.def.get("res", "")) in ["oil", "gas", "uranium"]):
			row.energy += value
		if b.key in FOOD:
			row.food += value
		row.homes += float(b.def.get("provides", {}).get("civCap", 0.0)) + float(TOWN_PEOPLE.get(b.key, 0.0)) * 0.5
	return m

## A nation's output as the statistics count it: what stands, with the capital, against the normal size
## (in full below it; with diminishing returns above it, so a sprawling economy is not ten times the real one).
func development(id: int) -> float:
	var d := float(of(id).out) / NORMAL_OUTPUT
	return d if d <= 1.0 else sqrt(d)

## How hard what stands is working: blackouts, a falling currency, default, turmoil, war and sanctions.
func activity(id: int) -> float:
	var s := of(id)
	var a := 1.0 - 0.35 * _loss(s, "energy")
	if s.crises.has("currency"): a *= 0.9
	if s.crises.has("default"): a *= 0.85
	if s.crises.has("political"): a *= 0.93
	if s.crises.has("collapse"): a *= 0.85
	if s.crises.has("isolation"): a *= 0.97
	if w.diplomacy != null and not w.diplomacy.enemies_of(id).is_empty(): a *= 0.95
	a *= FactionPowers.income_mult(w, id)
	return clampf(a, 0.2, 1.1)

func _loss(s: Dictionary, what: String) -> float:
	var peak: float = float(s.get(what + "_peak" if what != "out" else "peak", 0.0))
	var floor_at := 3.0 if what != "food" else 2.0
	if peak < floor_at:
		return 0.0
	var scale := maxf(peak, SMALL) if what == "out" else peak
	return clampf((peak - float(s.get(what, 0.0))) / scale, 0.0, 1.0)

## The share of the people without a home.
func displaced_share(id: int) -> float:
	var s := of(id)
	return clampf(float(s.displaced) / maxf(float(s.homes) + float(s.displaced), 1.0), 0.0, 1.0)

## The fragility index (0 to 120, as the Fragile States Index: higher is worse).
func fragility(id: int) -> float:
	return clampf(float(base_of(id)[4]) + float(of(id).pressure), 0.0, 120.0)

## The rating score (0 to 100) the markets would give, and its letters.
func rating_score(id: int, with_default := true) -> float:
	var s := of(id)
	var b: Array = base_of(id)
	var f := fragility(id)
	var score := 100.0 - maxf(0.0, float(s.debt) - 60.0) * 0.15 - maxf(0.0, float(s.inflation) - 3.0) * 0.6 - f * 0.25 - maxf(0.0, f - 60.0) * 0.6
	score -= _loss(s, "out") * 30.0 + _loss(s, "energy") * 10.0
	if w.diplomacy != null and not w.diplomacy.enemies_of(id).is_empty():
		score -= 5.0
	if with_default and s.crises.has("default"):
		return 0.0
	return clampf(score, 0.0, 100.0)

static func rating_letters(score: float) -> String:
	for r in [[85.0, "AAA"], [75.0, "AA"], [65.0, "A"], [55.0, "BBB"], [45.0, "BB"], [35.0, "B"], [25.0, "CCC"], [15.0, "CC"], [1.0, "C"]]:
		if score >= r[0]:
			return r[1]
	return "D"

func rating(id: int) -> String:
	return rating_letters(rating_score(id))

## Time passes: every nation measured, its indicators moved, its crises begun and ended.
func step(dt: float) -> void:
	var now := float(w.game_time)
	var measured := _measure()
	for id in range(w.map.nations.size()):
		if id > 0 and w.diplomacy != null and w.diplomacy.defeated(id):
			continue
		var s := of(id)
		var m: Dictionary = measured.get(id, {"out": 0.0, "energy": 0.0, "food": 0.0, "homes": 0.0})
		for key in ["out", "energy", "food"]:
			var peak_key: String = "peak" if key == "out" else key + "_peak"
			s[key] = float(m[key])
			s[peak_key] = maxf(float(s[key]), float(s[peak_key]) - (float(s[peak_key]) - float(s[key])) * dt / ADAPT)
		s.homes = float(m.homes)
		s.displaced = float(s.displaced) * exp(-dt / 300.0)   # people find shelter, return or resettle
		s.condemn = maxf(0.0, float(s.condemn) - CONDEMN_DECAY * dt)
		_indicators(id, s, dt)
		_crises(id, s, now)
		s.seen = true
	_follow_player()

func _indicators(id: int, s: Dictionary, dt: float) -> void:
	var b: Array = base_of(id)
	var loss := _loss(s, "out")
	var e_loss := _loss(s, "energy")
	var f_loss := _loss(s, "food")
	var at_war: bool = w.diplomacy != null and not w.diplomacy.enemies_of(id).is_empty()
	var sanctions := 1.0 - FactionPowers.income_mult(w, id)
	var shelter := displaced_share(id)
	# Prices: lost supply, dear energy and food, war spending, sanctions and default.
	var infl := float(b[0]) + 30.0 * loss + 25.0 * e_loss + 15.0 * f_loss + (4.0 if at_war else 0.0) + 40.0 * sanctions + (25.0 if s.crises.has("default") else 0.0)
	s.inflation = float(s.inflation) + (infl - float(s.inflation)) * minf(1.0, dt / 90.0)
	# Jobs: workplaces destroyed, factories without power, people without homes.
	var jobless := float(b[1]) + 35.0 * loss + 10.0 * e_loss + 15.0 * shelter
	s.unemployment = float(s.unemployment) + (jobless - float(s.unemployment)) * minf(1.0, dt / 120.0)
	# Defence spending: doubled at war, a bigger share of a shrinking economy.
	var milex := float(b[3]) * (1.8 if at_war else 1.0) / maxf(0.3, 1.0 - loss)
	s.milex = clampf(float(s.milex) + (milex - float(s.milex)) * minf(1.0, dt / 120.0), 0.0, 60.0)
	# Public debt (% of GDP): the deficit adds to it; a shrinking economy raises the ratio at once,
	# a growing one lowers it slowly.
	var deficit := 2.5 + (7.0 if at_war else 0.0) + 12.0 * loss + 0.5 * maxf(0.0, float(s.milex) - float(b[3])) - (3.0 if not at_war and loss < 0.05 else 0.0)
	s.debt = float(s.debt) + deficit * dt / YEAR
	var g := maxf(float(s.out), 0.5) * activity(id)
	if float(s.g_prev) > 0.0:
		var ratio := float(s.g_prev) / g
		s.debt = float(s.debt) * (clampf(ratio, 1.0, 1.5) if ratio > 1.0 else pow(ratio, 0.1))
	s.g_prev = g
	s.debt = clampf(float(s.debt), 0.0, 400.0)
	# Pressure on the state (the fragility index above its usual level).
	var pressure := 35.0 * loss + 15.0 * e_loss + 10.0 * f_loss + minf(15.0, maxf(0.0, float(s.inflation) - float(b[0])) / 3.0) \
		+ maxf(0.0, float(s.unemployment) - float(b[1])) * 0.6 + 20.0 * shelter + (8.0 if s.crises.has("default") else 0.0) + (4.0 if s.crises.has("isolation") else 0.0)
	if w.support != null:
		pressure += maxf(0.0, 50.0 - float(w.support.value(id))) * 0.3
		if w.support.regime(id) == "autocracy":
			pressure *= 0.8   # a state that represses dissent holds longer
	var tau := 40.0 if pressure > float(s.pressure) else 150.0
	s.pressure = float(s.pressure) + (pressure - float(s.pressure)) * minf(1.0, dt / tau)
	if float(s.score0) < 0.0:
		s.score0 = rating_score(id, false)

## Crises begin and end (with hysteresis), and do what they do while they last.
func _crises(id: int, s: Dictionary, now: float) -> void:
	var b: Array = base_of(id)
	var loss := _loss(s, "out")
	var e_loss := _loss(s, "energy")
	var f_loss := _loss(s, "food")
	_switch(id, "depression", loss >= 0.4, loss < 0.25)
	_switch(id, "recession", loss >= 0.15 and not s.crises.has("depression"), loss < 0.08 or s.crises.has("depression"))
	_switch(id, "energy", e_loss >= 0.4, e_loss < 0.2)
	_switch(id, "food", f_loss >= 0.5, f_loss < 0.25)
	_switch(id, "currency", float(s.inflation) >= maxf(30.0, float(b[0]) + 25.0), float(s.inflation) < maxf(20.0, float(b[0]) + 12.0))
	var score := rating_score(id, false)
	# A default needs a ruined rating, debt well past what the nation usually carries, and an economy that has
	# been in depression or currency crisis for two minutes (a state that borrows in its own money prints first).
	var ruined: bool = (s.crises.has("depression") and now - float(s.crises.depression) >= 120.0) or (s.crises.has("currency") and now - float(s.crises.currency) >= 120.0)
	_switch(id, "default", ruined and score < 10.0 and float(s.debt) > maxf(100.0, float(b[2]) + 50.0) and score < float(s.score0) - 15.0, score > 35.0 or score >= float(s.score0) - 5.0)
	var shelter := displaced_share(id)
	_switch(id, "humanitarian", shelter >= 0.15, shelter < 0.07)
	_switch(id, "political", float(s.pressure) >= 25.0, float(s.pressure) < 15.0)
	_switch(id, "isolation", float(s.condemn) >= CONDEMN_AT, float(s.condemn) < 2.0)
	if s.crises.has("collapse") and now - float(s.crises.collapse) >= AFTERMATH:
		_end(id, "collapse")
	if float(s.pressure) >= 45.0 and now - float(s.fell_at) >= FALL_AGAIN and s.crises.has("political") and now - float(s.crises.political) >= PROTEST_BEFORE_FALL:
		_fall(id, s, now)
	# The people's support for the war drains while the crises last.
	if w.support != null:
		var drain := 0.0
		for k in s.crises:
			drain += float(KINDS[k].drain)
		if drain > 0.0:
			w.support.change(id, -drain * STEP * w.support.sensitivity(id))

func _switch(id: int, kind: String, start: bool, stop: bool) -> void:
	var pending: Dictionary = of(id).pending
	if active(id, kind):
		pending.erase(kind)
		if stop:
			_end(id, kind)
	elif start:
		if not pending.has(kind):
			pending[kind] = float(w.game_time)
		if float(w.game_time) - float(pending[kind]) >= HOLD or not of(id).seen:
			pending.erase(kind)
			_begin(id, kind)
	else:
		pending.erase(kind)

func _begin(id: int, kind: String) -> void:
	var s := of(id)
	s.crises[kind] = float(w.game_time)
	if not s.seen:
		return   # (a nation's first measure is no news)
	var k: Dictionary = KINDS[kind]
	if id == 0:
		_say("CRISIS: %s. %s" % [k.title, k.text])
	elif k.public and float(w.game_time) - _last_news >= NEWS_GAP:
		_last_news = float(w.game_time)
		_say("World news: %s in %s: %s" % [k.title.to_lower() if kind != "default" else "a sovereign default", w.diplomacy.name_of(id), _rival_text(id, kind)])

func _end(id: int, kind: String) -> void:
	var s := of(id)
	s.crises.erase(kind)
	if id == 0:
		_say("Recovery: the %s is over." % str(KINDS[kind].title).to_lower())

func _rival_text(id: int, kind: String) -> String:
	match kind:
		"depression": return "its industry and towns in ruins, output has collapsed."
		"energy": return "blackouts across the country after the loss of its power stations."
		"currency": return "its currency is in free fall and prices soar."
		"default": return "it cannot pay its creditors."
		"humanitarian": return "a large share of its people have lost their homes."
		"political": return "mass protests against the government."
		"isolation": return "it is condemned for strikes on homes, power stations and hospitals."
		_: return str(KINDS[kind].text)

## The pressure has passed what a government can bear.
func _fall(id: int, s: Dictionary, now: float) -> void:
	s.fell_at = now
	s.pressure = float(s.pressure) - 15.0   # a new government, a fresh start
	var regime: String = w.support.regime(id) if w.support != null else "hybrid"
	var name: String = "your" if id == 0 else w.diplomacy.name_of(id) + "'s"
	if regime == "autocracy":
		# The regime holds by force: no peace, but the economy and its name abroad suffer.
		s.crises["collapse"] = now
		if id == 0:
			_say("CRISIS: Crackdown. The protests are put down by force; the state survives, but income -12% and production -10% for three minutes, and the democracies think less of you.")
		else:
			_say("World news: %s's regime cracks down on mass protests." % w.diplomacy.name_of(id))
		if w.diplomacy != null and w.support != null:
			for other in range(w.map.nations.size()):
				if other != id and w.support.regime(other) == "democracy":
					w.diplomacy.change(id, other, -6.0)
		return
	s.crises["collapse"] = now
	var ended := []
	if w.diplomacy != null:
		for enemy in w.diplomacy.enemies_of(id):
			w.diplomacy.make_peace(id, enemy)
			ended.append("you" if enemy == 0 else w.diplomacy.name_of(enemy))
	var peace := (" The new government signs a ceasefire with %s." % ", ".join(PackedStringArray(ended))) if not ended.is_empty() else ""
	if id == 0:
		_say("CRISIS: Government collapse. Under the weight of the crises %s government has fallen.%s Income -12%%, production -10%% for three minutes." % [name, peace])
	else:
		_say("World news: %s government falls under the weight of its crises.%s" % [name, peace])

# ---------------------------------------------------------------- events

## A building you demolished (world.demolish): a choice, not a loss: what it produced leaves the measure.
func demolished(b: Dictionary) -> void:
	if not b.get("built", false):
		return
	var s := of(int(b.owner))
	var value: float = float(b.def.get("cost", {}).get("money", 100.0)) / 100.0
	var cat := str(b.def.get("cat", ""))
	if cat != "military":
		s.peak = maxf(0.0, float(s.peak) - value * (0.6 if cat == "civic" else 1.0))
	if b.key in ENERGY or b.key == "extractor":
		s.energy_peak = maxf(0.0, float(s.energy_peak) - value)
	if b.key in FOOD:
		s.food_peak = maxf(0.0, float(s.food_peak) - value)

## A building destroyed (world.destroy_building): people lose homes; a striker of homes, power and
## hospitals is condemned.
func building_lost(b: Dictionary) -> void:
	var owner: int = int(b.owner)
	if owner < 0:
		return
	var s := of(owner)
	var people := float(b.def.get("provides", {}).get("civCap", 0.0)) + float(TOWN_PEOPLE.get(b.key, 0.0))
	if b.get("built", true):
		s.displaced = float(s.displaced) + people
	var by: int = int(b.get("last_by", -1))
	if by < 0 or by == owner or by >= w.map.nations.size():
		return
	var weight := 0.0
	if b.key in TOWN_PEOPLE:
		weight = 3.0
	elif b.key in ["hospital", "school", "university", "waterTreatment"]:
		weight = 2.0
	elif people > 0.0 or b.key in ENERGY or b.key in CIVILIAN or b.key in FOOD:
		weight = 1.0
	if weight <= 0.0:
		return
	var striker := of(by)
	var was: bool = float(striker.condemn) >= CONDEMN_AT
	striker.condemn = float(striker.condemn) + weight
	if not was and float(striker.condemn) >= CONDEMN_AT and not striker.crises.has("isolation"):
		striker.crises["isolation"] = float(w.game_time)
		_condemn(by, owner)

## The world turns on a striker of civilian infrastructure.
func _condemn(by: int, victim: int) -> void:
	var d: Node = w.diplomacy
	if d == null:
		return
	for other in range(w.map.nations.size()):
		if other == by or d.at_war(by, other) or d.allied(by, other):
			continue
		d.change(by, other, -8.0)
		if other != victim:
			d.change(victim, other, 3.0)   # sympathy for the victim
	var target: String = "you" if victim == 0 else d.name_of(victim)
	if by == 0:
		_say("CRISIS: International condemnation. Your strikes on %s homes, power stations and hospitals are condemned: the nations neither at war with you nor allied to you think less of you, and trade suffers (income -4%%). It eases as time passes without such strikes." % (d.name_of(victim) + "'s"))
	else:
		_say("World news: %s is condemned for its strikes on the homes and power stations of %s; nations distance themselves from it." % [d.name_of(by), target])

# ---------------------------------------------------------------- effects

## The player's crises as research bonuses (research._recompute).
func bonuses() -> Dictionary:
	var out := {}
	for k in of(0).crises:
		var fx: Dictionary = KINDS[k].player
		for stat in fx:
			out[stat] = float(out.get(stat, 0.0)) + float(fx[stat])
	return out

## A rival's income under its crises (ai.gd).
func ai_income_mult(id: int) -> float:
	var m := 1.0
	for k in of(id).crises:
		m *= float(KINDS[k].ai)
	return m

func _follow_player() -> void:
	var now := ",".join(PackedStringArray(list(0)))
	if now == _player_kinds:
		return
	_player_kinds = now
	if w.research != null:
		w.research._recompute()

func _say(text: String) -> void:
	notices += 1
	if w.hud != null:
		w.hud.notice(text)

## The player's crises, in words (the statistics' overview, the cabinet).
func describe(id: int) -> Array:
	var out := []
	for k in list(id):
		out.append({"kind": k, "title": KINDS[k].title, "group": KINDS[k].group, "text": KINDS[k].text, "since": float(of(id).crises[k])})
	return out

# ---------------------------------------------------------------- saves

func capture() -> Dictionary:
	var out := {}
	for id in state:
		out[str(id)] = state[id].duplicate(true)
	return {"state": out}

func restore(data: Dictionary) -> void:
	state = {}
	for key in data.get("state", {}):
		var s := _fresh(int(key))
		var saved: Dictionary = data.state[key]
		for f in saved:
			s[f] = saved[f] if f != "crises" else {}
		s.pending = {}
		for k in saved.get("crises", {}):
			if KINDS.has(k):
				s.crises[k] = float(saved.crises[k])
		state[int(key)] = s
	_player_kinds = ""
	_follow_player()
