extends RefCounted
## Each faction's strengths and weaknesses in every field (factions.gd ids):
## economy, science and technology, the military, politics and diplomacy,
## espionage, population and resources. Researched from 2024-2025 figures:
## R&D spending as a share of GDP (Israel 6.3%, US 3.5%, Japan 3.3%, China 2.6%,
## Russia 0.9%, India 0.6%), SIPRI 2024 military spending (US $997 bn, China
## $314 bn, Russia $149 bn at 7.1% of GDP, Israel 8.8% of GDP, Iran $7.9 bn),
## IMF 2025 growth (India 6.6%, China 4.8%, Turkiye 3.5% with 35% inflation,
## US 2.0%, euro area 1.2%, Japan 1.1%, Russia 0.6%), sanctions on Russia and
## Iran, energy exporters and importers, ageing and young populations.
## The numbers are game balance drawn from those facts, not rankings.
##
## For the player they flow through research.gd's bonus stats (incomePct,
## researchPct, spyPct, counterSpy, happiness, health, prodPct, buildPct,
## civCapPct, dmgAir, dmgNaval, dmgArty, dmgInfantry, dmgAll, hpAll);
## population growth, resources, trade and unit prices have their own hooks.
## Rival nations get the same through the AI's income, technology and prices.
##
## Income and research, for all 22 nations (here and additional_factions.gd), from one scale (2026-10-03,
## native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md, "All 22"): 15 points for every tenfold, from the
## world's level, rounded to 5. Income: GDP a head (World Bank 2024; North Korea, Bank of Korea), less the
## oil rents where the game already pays oil (Saudi Arabia, Iraq). Research: scientific articles per
## million people (World Bank, 2023); Afghanistan's times the 72% of students left after the ban on women.

const PROFILES := {
	"usa": {
		"bonus": {"incomePct": 0.1, "researchPct": 0.05, "spyPct": 0.1, "dmgAir": 0.1, "happiness": 2.0},
		"growth": 1.05, "resources": {"oil": 1.2, "gas": 1.2}, "trade": 1.05,
		"costs": {"air": 0.9, "armor": 1.1, "artillery": 1.1},
		"strengths": ["Largest economy and the dollar: +10% income", "Research: +5% (three times the world's scientific output a head)", "Air power: aircraft 10% cheaper, +10% air damage", "Shale oil and gas: +20% output", "Intelligence: +10% covert success"],
		"weaknesses": ["Expensive forces: tanks and artillery cost 10% more", "Rivals everywhere: cold relations with China, Russia and Iran"],
	},
	"china": {
		"bonus": {"researchPct": 0.05, "prodPct": 0.15, "buildPct": 0.15, "spyPct": 0.1, "counterSpy": 0.1},
		"growth": 0.9, "resources": {"silicon": 1.3, "oil": 0.8}, "trade": 1.15,
		"costs": {"naval": 0.85},
		"strengths": ["The world's factory: +15% production and construction speed", "Shipbuilding: warships 15% cheaper", "Rare earths and chips: +30% silicon", "Exports: +15% trade income", "Research +5%, cyber espionage +10%, counter-intelligence +10%"],
		"weaknesses": ["An ageing population: 10% slower growth", "Imports its oil: -20% oil output", "Cold relations with the US, Japan and India"],
	},
	"eu": {
		"bonus": {"incomePct": 0.05, "researchPct": 0.05, "happiness": 4.0, "health": 5.0, "dmgAll": -0.05},
		"growth": 0.65, "resources": {"oil": 0.7, "gas": 0.6}, "trade": 1.15,
		"costs": {"airDefence": 0.9},
		"strengths": ["The single market: +5% income, +15% trade income", "Welfare and health: +4 happiness, +5 health", "Research +5%", "Air defence 10% cheaper (IRIS-T, SAMP/T)"],
		"weaknesses": ["Dependent on imported energy: -30% oil, -40% gas output", "Low readiness after decades of peace: -5% combat damage", "An ageing population: the population grows a third slower, despite the welfare"],
	},
	"iran": {
		"bonus": {"incomePct": -0.05, "researchPct": 0.05, "happiness": -6.0, "spyPct": 0.05},
		"growth": 1.0, "resources": {"oil": 1.4, "gas": 1.4}, "trade": 0.75,
		"costs": {"drone": 0.75, "missile": 0.75},
		"strengths": ["Oil and gas: +40% output", "Asymmetric arsenal: drones and missiles 25% cheaper", "Covert networks across the region: +5% covert success", "Universities: +5% research despite the sanctions"],
		"weaknesses": ["Sanctions: -5% income and -25% trade income", "High inflation and unrest: -6 happiness", "Hostile to the US and Israel from the start"],
	},
	"russia": {
		"bonus": {"researchPct": 0.05, "spyPct": 0.1, "happiness": -3.0, "hpAll": 0.05},
		"growth": 0.8, "resources": {"oil": 1.5, "gas": 1.6, "iron": 1.2}, "trade": 0.75,
		"costs": {"armor": 0.85, "artillery": 0.85},
		"strengths": ["Energy superpower: +50% oil, +60% gas output, +20% iron", "Mass-produced armour and artillery: 15% cheaper", "A hardened army: +5% health", "Intelligence services: +10% covert success", "Research +5%"],
		"weaknesses": ["Sanctions: -25% trade income", "A shrinking population: 20% slower growth, -3 happiness", "Hostile to the US and the EU from the start"],
	},
	"india": {
		"bonus": {"incomePct": -0.1, "researchPct": -0.05, "buildPct": 0.1, "happiness": -2.0, "hpInfantry": 0.1},
		"growth": 1.4, "resources": {"iron": 1.15}, "trade": 1.05,
		"costs": {"infantry": 0.9},
		"strengths": ["The fastest-growing large economy and youngest population: 40% faster growth", "Vast manpower: infantry 10% cheaper and +10% infantry health", "Friends in every camp: warm starting relations with the US and Russia alike", "+10% construction, +15% iron"],
		"weaknesses": ["Low research spending (0.6% of GDP): -5% research", "Poverty and strain: -10% income, -2 happiness", "Border rivalry with China"],
	},
	"japan": {
		"bonus": {"incomePct": 0.05, "researchPct": 0.05, "happiness": 5.0, "health": 8.0, "prodPct": 0.1},
		"growth": 0.5, "resources": {"oil": 0.6, "gas": 0.6, "iron": 0.8}, "trade": 1.1,
		"costs": {"naval": 0.9, "infantry": 1.1},
		"strengths": ["Technology: +5% research, +5% income, +10% production", "A stable, healthy society: +5 happiness, +8 health", "Shipbuilding: warships 10% cheaper", "An alliance with the US from the start"],
		"weaknesses": ["No resources of its own: -40% oil and gas, -20% iron", "The oldest population: it grows at half the pace", "A small army under a pacifist constitution: infantry 10% dearer"],
	},
	"turkiye": {
		"bonus": {"happiness": -4.0, "prodPct": 0.1, "buildPct": 0.1},
		"growth": 1.0, "resources": {}, "trade": 1.1,
		"costs": {"drone": 0.8},
		"strengths": ["The drone industry (Baykar): drones 20% cheaper", "The crossroads of Europe and Asia: +10% trade income", "Industry and construction +10%", "Talks with every side: mild relations with all"],
		"weaknesses": ["Inflation (35% in 2025): -4 happiness"],
	},
	"israel": {
		"bonus": {"incomePct": 0.1, "researchPct": 0.1, "spyPct": 0.15, "counterSpy": 0.15, "civCapPct": -0.15, "happiness": -2.0},
		"growth": 1.15, "resources": {"gas": 1.2}, "trade": 1.0,
		"costs": {},
		"strengths": ["The start-up nation: +10% research (R&D 6.3% of GDP, the world's highest), +10% income", "Mossad and Shin Bet: +15% covert success, +15% counter-intelligence", "Offshore gas (Leviathan): +20% gas", "An alliance with the US from the start"],
		"weaknesses": ["A small country: 15% less room for citizens", "Under constant threat: -2 happiness", "Surrounded by enemies: hostile to Iran from the start"],
	},
}

## Starting relations between factions that are present in a match, added to
## the usual random start: alliances, partnerships and old enmities.
const TIES := [
	["usa", "eu", 30.0], ["usa", "japan", 35.0], ["usa", "israel", 35.0], ["usa", "india", 10.0], ["usa", "turkiye", 5.0],
	["usa", "china", -20.0], ["usa", "russia", -35.0], ["usa", "iran", -55.0],
	["eu", "japan", 15.0], ["eu", "russia", -40.0], ["eu", "iran", -15.0], ["eu", "turkiye", 5.0],
	["china", "russia", 30.0], ["china", "iran", 15.0], ["china", "japan", -25.0], ["china", "india", -20.0],
	["russia", "iran", 25.0], ["russia", "india", 15.0], ["russia", "turkiye", 5.0],
	["iran", "israel", -70.0], ["israel", "turkiye", -15.0], ["india", "israel", 15.0], ["japan", "india", 15.0],
]

const UNIT_GROUPS := {
	"air": ["jet", "bomber", "helicopter", "gunship", "stealthFighter", "raptor", "raider", "sixthGen"],
	"drone": ["drone", "loiterer", "fpvTeam", "akinci", "harop", "shahedLauncher"],
	"naval": ["gunboat", "corvette", "destroyer", "submarine", "nuclearSub", "seaDrone", "railgunShip", "orca", "aegisCruiser"],
	"armor": ["tank", "apc"],
	"artillery": ["artillery", "mlrs", "himars", "tos1a"],
	"airDefence": ["aaVehicle", "samLauncher", "irisT", "laserAD", "abmLauncher", "manpads"],
	"infantry": ["soldier", "rocketSoldier", "sniper", "commando", "atgmTeam", "medic"],
}

static func id_of(w: Node, owner: int) -> String:
	if w == null or w.map == null or owner < 0 or owner >= w.map.nations.size():
		return ""
	var n: Dictionary = w.map.nations[owner]
	if n.has("id"):
		return str(n.id)
	# The original four nations, known by flag, when no faction id is given.
	return {"#3b82f6": "usa", "#e0483e": "china", "#33b86e": "eu", "#e8a83a": "iran"}.get(str(n.get("color", "")).to_lower(), "")

static func of(w: Node, owner: int) -> Dictionary:
	return PROFILES.get(id_of(w, owner), preload("res://scripts/additional_factions.gd").PROFILES.get(id_of(w, owner), {}))

## Research bonus stats for the player's nation (research._recompute adds them).
static func bonuses(w: Node, owner := 0) -> Dictionary:
	return of(w, owner).get("bonus", {})

static func growth(w: Node, owner: int) -> float:
	return float(of(w, owner).get("growth", 1.0))

static func resource_mult(w: Node, owner: int, res: String) -> float:
	return float(of(w, owner).get("resources", {}).get(res, 1.0))

static func trade_mult(w: Node, owner: int) -> float:
	return float(of(w, owner).get("trade", 1.0))

static func group_of(key: String) -> String:
	key = preload("res://scripts/additional_factions.gd").base(key)
	for g in UNIT_GROUPS:
		if key in UNIT_GROUPS[g]:
			return g
	return ""

## Price multiplier for `key` (a unit, or "missile" for a silo's missiles).
static func cost_mult(w: Node, owner: int, key: String) -> float:
	var p := of(w, owner)
	if p.get("unit_costs", {}).has(key): return float(p.unit_costs[key])
	var costs: Dictionary = p.get("costs", {})
	if key == "missile":
		return float(costs.get("missile", 1.0))
	return float(costs.get(group_of(key), 1.0))

## A rival nation's income, research pace and damage (the player's come
## through the bonus stats instead).
static func ai_income(w: Node, owner: int) -> float:
	return maxf(0.5, 1.0 + float(bonuses(w, owner).get("incomePct", 0.0)))

static func ai_research(w: Node, owner: int) -> float:
	return maxf(0.5, 1.0 + float(bonuses(w, owner).get("researchPct", 0.0)) + preload("res://scripts/additional_powers.gd").bonus(w, owner, "researchPct"))

static func ai_damage(w: Node, unit: Dictionary) -> float:
	var b := bonuses(w, int(unit.get("owner", -1)))
	var m := 1.0 + float(b.get("dmgAll", 0.0))
	if unit.get("fly", false): m += float(b.get("dmgAir", 0.0))
	if unit.get("naval", false): m += float(b.get("dmgNaval", 0.0))
	return m

static func ai_health(w: Node, unit: Dictionary) -> float:
	var b := bonuses(w, int(unit.get("owner", -1)))
	var m := 1.0 + float(b.get("hpAll", 0.0))
	if unit.get("key", "") in w.infantry_keys: m += float(b.get("hpInfantry", 0.0))
	return m

## Starting relations: each pair's tie added to the random start.
static func apply_relations(w: Node) -> void:
	var d: Node = w.diplomacy
	if d == null:
		return
	for a in range(d.n):
		for b in range(a + 1, d.n):
			var tie := tie_between(id_of(w, a), id_of(w, b))
			if tie != 0.0:
				d.set_score(a, b, clampf(d.rel(a, b) * 0.5 + tie, -95.0, 95.0))

static func tie_between(x: String, y: String) -> float:
	for t in TIES + preload("res://scripts/additional_factions.gd").TIES:
		if (t[0] == x and t[1] == y) or (t[0] == y and t[1] == x):
			return float(t[2])
	return 0.0

## Strengths and weaknesses of `id`, for the interface.
static func summary(id: String) -> Dictionary:
	var p: Dictionary = PROFILES.get(id, preload("res://scripts/additional_factions.gd").PROFILES.get(id, {}))
	return {"strengths": p.get("strengths", []), "weaknesses": p.get("weaknesses", [])}
