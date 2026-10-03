extends RefCounted
## Research snapshot 2026-10-02. See native/FACTIONS-RESEARCH-2026-10-02.md.
## Iraq, Syria and Afghanistan: 2026-10-03, native/NATIONS-IRAQ-SYRIA-AFGHANISTAN-2026-10-03.md.
## Numerical modifiers are game balance, never claims about real effectiveness.
const IDS := ["uk", "south_korea", "saudi", "brazil", "indonesia", "ukraine", "north_korea", "egypt", "australia", "pakistan", "iraq", "syria", "afghanistan"]
## Claim existing capital slots without changing the parallel map work's geometry.
const CITY_FACTIONS := {"Riyadh": "saudi", "Kyiv": "ukraine", "Seoul": "south_korea", "Jakarta": "indonesia", "Baghdad": "iraq"}
const NAMES := ["United Kingdom", "South Korea", "Saudi Arabia", "Brazil", "Indonesia", "Ukraine", "North Korea", "Egypt", "Australia", "Pakistan", "Iraq", "Syria", "Afghanistan"]
const LEADERS := ["Prime Minister Andy Burnham", "President Lee Jae Myung", "Crown Prince and Prime Minister Mohammed bin Salman", "President Luiz Inacio Lula da Silva", "President Prabowo Subianto", "President Volodymyr Zelenskyy", "General Secretary Kim Jong Un", "President Abdel Fattah el-Sisi", "Prime Minister Anthony Albanese", "Prime Minister Shehbaz Sharif", "Prime Minister Ali al-Zaidi", "President Ahmed al-Sharaa", "Supreme Leader Hibatullah Akhundzada"]
const COLOURS := ["#bc354b", "#6d92bf", "#368250", "#a2b83f", "#ed6550", "#e7c443", "#905059", "#c38c52", "#628a9e", "#6c9560", "#a0522d", "#5d6d7e", "#d9d4c5"]
const PORTRAITS := ["burnham", "lee", "bin-salman", "lula", "prabowo", "zelenskyy", "kim", "sisi", "albanese", "sharif", "zaidi", "sharaa", "akhundzada"]
const SIGNATURES := ["Type 45 Destroyer", "K9 Thunder", "Saudi THAAD", "A-29 Super Tucano", "KCR-60", "Interceptor Drone", "Heavy Rocket Launcher", "Engineering Corps", "Bushmaster", "JF-17 Thunder", "Golden Division (CTS)", "Shaheen Drone Team", "Suicide Attack Squad"]
const DOCTRINES := [
	"Maritime protection: Type 45 air defence protects commerce. Expensive infantry and slower population growth reward a compact force.",
	"Mobile industry: K9 artillery reloads and moves quickly. Strong research and production depend on imported energy.",
	"Energy into development: oil finances construction and research. THAAD protects against ballistic missiles; food and aircraft are costly.",
	"Food diplomacy: farms sustain exports and aid shipments. A-29 light aircraft support ground forces but cannot fight jets.",
	"Coastal development: fishing and affordable ports support villages. Fast KCR-60 boats strike ships then retreat during long reloads.",
	"Recovery and interception: cheaper route repairs and fast drone production. Interceptor drones engage only hostile airborne drones.",
	"Fortified firepower: durable bunkers and heavy rocket salvos. Artillery readiness diverts money from an already weak trade economy.",
	"Logistics hub: cheaper routes and faster shipments. Engineering Corps workers build 25% faster; civilians consume more food.",
	"Resource frontier: iron and uranium fund a compact army. Bushmasters resist explosive attacks but lack anti-tank firepower.",
	"Defence partnerships: affordable fighters and fast infantry recruitment. Joint research requires a living ally and ends if the alliance breaks.",
	"Oil state between two patrons: oil pays for an army of Abrams and F-16IQs, and the Popular Mobilization raises militias at a call, at a price in Washington. Drought cuts the harvest; no nuclear or missile programme.",
	"Rebuilding after the war: battle-hardened infantry and cheap Shaheen drones. No jets, no attack helicopters, no navy and no strategic air defence: partners pay for the reconstruction.",
	"Insurgency: cheap, fast-raised, hardy infantry, suicide attack squads and attacks deep inside an enemy country. No air force, no navy, no nuclear reactor; sanctions and isolation starve its economy and research."
]
const PROFILES := {
	"uk": {"bonus": {"spyPct": 0.1}, "growth": 0.85, "trade": 1.15, "costs": {"infantry": 1.1}, "strengths": ["Trade income +15%", "Covert success +10%", "Type 45 fleet air defence"], "weaknesses": ["Infantry costs +10%", "Population growth -15%"]},
	"south_korea": {"bonus": {"researchPct": 0.2, "prodPct": 0.15}, "growth": 0.8, "resources": {"oil": 0.75, "gas": 0.75}, "costs": {"armor": 0.9, "artillery": 0.9}, "strengths": ["Research +20%, production +15%", "Armour and artillery costs -10%"], "weaknesses": ["Oil and gas output -25%", "Population growth -20%"]},
	"saudi": {"bonus": {"incomePct": 0.1, "foodPct": -0.25}, "resources": {"oil": 1.6}, "costs": {"air": 1.15}, "strengths": ["Oil output +60%, income +10%", "Investment accelerates construction and research"], "weaknesses": ["Farm output -25%", "Crewed aircraft costs +15%"]},
	"brazil": {"bonus": {"foodPct": 0.3, "prodPct": -0.1}, "resources": {"iron": 1.15}, "trade": 1.1, "costs": {"airDefence": 1.15}, "strengths": ["Farm output +30%, iron +15%", "Trade income +10%; deliver food for goodwill"], "weaknesses": ["Production -10%", "Air defence costs +15%"]},
	"indonesia": {"bonus": {"researchPct": -0.1}, "fishing": 1.25, "build_costs": {"port": 0.85, "villageCenter": 0.85}, "costs": {"air": 1.15}, "strengths": ["Fishing output +25%", "Ports and village centres cost -15%", "Nutrition programme improves health and happiness"], "weaknesses": ["Research -10%", "Crewed aircraft costs +15%"]},
	"ukraine": {"bonus": {"incomePct": -0.1}, "repair_cost": 0.75, "train": {"drone": 1.2}, "costs": {"air": 1.15}, "strengths": ["Road and rail repair costs -25%", "Drone production +20%", "Emergency reconstruction restores damaged buildings"], "weaknesses": ["Income -10%", "Crewed aircraft costs +15%"]},
	"north_korea": {"bonus": {"researchPct": -0.2}, "trade": 0.7, "build_costs": {"bunker": 0.8}, "unit_costs": {"mlrs": 0.85, "heavyRocket": 0.85}, "strengths": ["Bunkers cost -20% and have +25% health", "Rocket launchers cost -15%", "Short bursts of artillery readiness"], "weaknesses": ["Trade income -30%, research -20%", "Readiness reduces income for 90 seconds"]},
	"egypt": {"bonus": {"researchPct": -0.1}, "trade": 1.15, "road_cost": 0.8, "civilian_food": 1.1, "strengths": ["Road and rail costs -20%", "Trade income +15%", "Engineering Corps workers build 25% faster"], "weaknesses": ["Research -10%", "Civilian food consumption +10%"]},
	"australia": {"bonus": {"researchPct": 0.1, "civCapPct": -0.15}, "resources": {"iron": 1.25, "uranium": 1.25}, "costs": {"infantry": 1.2}, "strengths": ["Iron and uranium output +25%, research +10%", "Mining boom accelerates supplied extractors"], "weaknesses": ["Infantry costs +20%", "Civilian capacity -15%"]},
	"pakistan": {"bonus": {"incomePct": -0.1}, "train": {"infantry": 1.15}, "unit_costs": {"jet": 0.85, "jf17": 0.85}, "costs": {"naval": 1.2}, "strengths": ["Conventional fighters cost -15%", "Infantry recruitment +15%", "Joint research with an ally"], "weaknesses": ["Income -10%", "Warship costs +20%"]},
	"iraq": {"bonus": {"researchPct": -0.15, "foodPct": -0.2}, "resources": {"oil": 1.5, "gas": 0.75}, "costs": {"air": 1.1}, "strengths": ["Oil output +50%", "Popular Mobilization raises six militia fighters at a call", "Golden Division counter-terrorism troops"], "weaknesses": ["Research -15%, farm output -20% (drought)", "Gas output -25%; crewed aircraft cost +10%", "No submarines, missile silo or nuclear reactor"]},
	"syria": {"bonus": {"incomePct": -0.25, "researchPct": -0.2, "hpInfantry": 0.1}, "resources": {"oil": 0.7}, "train": {"drone": 1.25, "infantry": 1.15}, "costs": {"infantry": 0.9}, "strengths": ["Infantry +10% health, -10% cost, recruited 15% faster", "Drones produced 25% faster; Shaheen drone teams", "Reconstruction aid from its partners"], "weaknesses": ["Income -25%, research -20%, oil -30%", "No jets, attack helicopters, warships or strategic air defence", "No missile silo or nuclear reactor"]},
	# Calibrated 2026-10-03 (see the research doc, "Calibration"): income on the scale the game already gives
	# Pakistan (-10%, $1,485 a head) and Egypt (0%, about $3,400): $417 a head comes to -25%. Research: North
	# Korea's -20% for output as low as any, times the 28% of students the ban on women removed, comes to -40%.
	# Trade -40%: trade with Pakistan fell 40% in 2025, the border shut since October 2025. Happiness -8: the
	# world's least happy nation (World Happiness Report, last six years) takes the game's largest single effect.
	"afghanistan": {"bonus": {"incomePct": -0.25, "researchPct": -0.4, "hpInfantry": 0.15, "happiness": -8}, "resources": {"iron": 1.2}, "trade": 0.6, "train": {"infantry": 1.3}, "costs": {"infantry": 0.8, "armor": 1.25}, "strengths": ["Infantry +15% health, -20% cost, recruited 30% faster", "Suicide attack squads; insurgent attacks deep in an enemy country", "Iron output +20% (mines)"], "weaknesses": ["Income -25%, research -40% (women barred from study), trade -40% (borders shut, sanctions)", "No air force, navy, strategic air defence, missiles or nuclear reactor", "Armour costs +25%; happiness -8"]}
}
const TIES := [["uk", "usa", 25.0], ["uk", "eu", 20.0], ["uk", "ukraine", 30.0], ["uk", "russia", -30.0], ["south_korea", "usa", 25.0], ["south_korea", "japan", 10.0], ["south_korea", "north_korea", -65.0], ["saudi", "usa", 15.0], ["saudi", "pakistan", 20.0], ["saudi", "iran", -20.0], ["brazil", "india", 10.0], ["brazil", "china", 15.0], ["indonesia", "japan", 10.0], ["ukraine", "eu", 30.0], ["ukraine", "russia", -75.0], ["north_korea", "russia", 25.0], ["north_korea", "china", 20.0], ["north_korea", "usa", -50.0], ["egypt", "saudi", 15.0], ["australia", "uk", 25.0], ["australia", "usa", 30.0], ["australia", "japan", 20.0], ["pakistan", "china", 30.0], ["pakistan", "india", -45.0],
	["iraq", "iran", 35.0], ["iraq", "usa", 5.0], ["iraq", "turkiye", -10.0], ["iraq", "saudi", 10.0], ["iraq", "china", 15.0], ["iraq", "israel", -45.0], ["iraq", "syria", 5.0],
	["syria", "turkiye", 40.0], ["syria", "saudi", 25.0], ["syria", "usa", 10.0], ["syria", "eu", 10.0], ["syria", "iran", -45.0], ["syria", "israel", -20.0], ["syria", "russia", -10.0],
	["afghanistan", "pakistan", -55.0], ["afghanistan", "russia", 15.0], ["afghanistan", "china", 10.0], ["afghanistan", "india", 5.0], ["afghanistan", "iran", -5.0], ["afghanistan", "usa", -45.0], ["afghanistan", "israel", -45.0], ["afghanistan", "uk", -30.0]]
## A suicide attack's toll over an attack by other means (4.4 against 1.14 killed: the research doc).
const SQUAD_FACTOR := 3.9
## Art models reuse the game's procedural chassis. Each unit has its own rules.
const BASE := {"ctsGolden": "commando", "shaheenDrone": "fpvTeam", "suicideSquad": "soldier", "type45": "destroyer", "k9": "artillery", "saudiThaad": "abmLauncher", "superTucano": "jet", "kcr60": "corvette", "interceptorDrone": "loiterer", "heavyRocket": "mlrs", "bushmaster": "apc", "jf17": "jet"}
const HOME := {"ctsGolden": "barracks", "shaheenDrone": "barracks", "suicideSquad": "barracks", "type45": "shipyard", "k9": "tankFactory", "saudiThaad": "tankFactory", "superTucano": "airfield", "kcr60": "shipyard", "interceptorDrone": "airfield", "heavyRocket": "tankFactory", "bushmaster": "tankFactory", "jf17": "airfield"}
const UNITS := {
	"type45": {"nation": "uk", "name": "Type 45 Destroyer", "requires": "guidedMunitions", "scale": {"range": 1.2, "cost": 1.25}, "desc": "UK only. Fleet air defence: 70% cruise and 65% sea-skimming interception within 200 m. Limited ground firepower; expensive."},
	"k9": {"nation": "south_korea", "name": "K9 Thunder", "requires": "compositeArmor", "scale": {"cooldown": 0.8, "speed": 1.15, "cost": 1.2}, "desc": "South Korea only. Mobile artillery: 20% shorter reload and 15% more speed than standard artillery; base cost +20%. National industry discounts apply."},
	"saudiThaad": {"nation": "saudi", "name": "Saudi THAAD", "requires": "missileDefence", "scale": {"hp": 1.2, "cost": 1.25}, "desc": "Saudi Arabia only. Hardened ballistic defence: 80% against short ballistic and 86% ballistic missiles within 253 m. Cannot engage aircraft, cruise missiles or ICBMs."},
	"superTucano": {"nation": "brazil", "name": "A-29 Super Tucano", "requires": "jetPropulsion", "scale": {"hp": 0.65, "speed": 0.75, "cost": 0.65}, "desc": "Brazil only. Affordable light ground attack aircraft, strongest against infantry and light vehicles. Cannot fight aircraft; vulnerable to air defence."},
	"kcr60": {"nation": "indonesia", "name": "KCR-60", "requires": "navalEngineering", "scale": {"speed": 1.3, "hp": 0.7, "cooldown": 1.5}, "desc": "Indonesia only. Fast missile boat: +30% speed and +25% anti-ship damage, but -30% health and 50% longer reload than a corvette."},
	"interceptorDrone": {"nation": "ukraine", "name": "Interceptor Drone", "requires": "microchips", "scale": {"speed": 1.3, "cost": 0.7}, "desc": "Ukraine only. A canister-launched, one-use interceptor. Engages airborne drones only; vulnerable to electronic warfare."},
	"heavyRocket": {"nation": "north_korea", "name": "Heavy Rocket Launcher", "requires": "ballisticTech", "scale": {"dmg": 1.35, "range": 1.2, "cooldown": 1.6, "speed": 0.8}, "desc": "North Korea only. Heavy rocket salvos: +35% damage and +20% range, but 60% longer reload and -20% speed. Needs protection between salvos."},
	"bushmaster": {"nation": "australia", "name": "Bushmaster", "requires": "compositeArmor", "scale": {"speed": 1.15, "hp": 1.15}, "desc": "Australia only. Protected mobility: +15% speed and health, takes 25% less explosive damage. Weak against tanks."},
	"jf17": {"nation": "pakistan", "name": "JF-17 Thunder", "requires": "jetPropulsion", "scale": {"hp": 0.85, "trainTime": 0.8}, "desc": "Pakistan only. Multirole fighter: trains 20% faster, with 15% less health. National fighter discount applies."},
	"ctsGolden": {"nation": "iraq", "name": "Golden Division (CTS)", "requires": "advancedLogistics", "scale": {"hp": 1.2, "cost": 1.15}, "desc": "Iraq only. The Counter-Terrorism Service: elite assault infantry, +20% health, and 40% more damage to buildings (street fighting, Mosul 2017). Base cost +15%."},
	"shaheenDrone": {"nation": "syria", "name": "Shaheen Drone Team", "requires": "microchips", "scale": {"cost": 0.75, "trainTime": 0.8, "hp": 0.9}, "desc": "Syria only. A team flying cheap FPV attack drones, as the Shaheen units did in 2024: 25% cheaper and 20% faster to train than an FPV team, 10% less health. Jammers bring many down."},
	"suicideSquad": {"nation": "afghanistan", "name": "Suicide Attack Squad", "requires": "advancedLogistics", "scale": {"hp": 0.8, "speed": 1.1, "range": 0.25, "cost": 1.5}, "desc": "Afghanistan only. Closes in and detonates: one blast, deadly to buildings, vehicles and infantry around it, and the squad is gone. Fragile on the approach; stopped by fire before it arrives."}
}
static func id_of(w: Node, owner: int) -> String:
	return str(w.map.nations[owner].get("id", "")) if owner >= 0 and owner < w.map.nations.size() else ""
static func profile(w: Node, owner: int) -> Dictionary:
	return PROFILES.get(id_of(w, owner), {})
static func base(key: String) -> String:
	return BASE.get(key, key)
static func apply(w: Node) -> void:
	for key in UNITS:
		var entry: Dictionary = UNITS[key]
		var def: Dictionary = w.unit_defs[BASE[key]].duplicate(true)
		for stat in entry.scale:
			if stat == "cost":
				for resource in def.cost: def.cost[resource] = ceilf(float(def.cost[resource]) * float(entry.scale[stat]))
			else: def[stat] = float(def[stat]) * float(entry.scale[stat])
		def.merge({"nation": entry.nation, "name": entry.name, "requires": entry.requires, "desc": entry.desc}, true)
		def.aggro = maxf(float(def.get("aggro", 0.0)), float(def.range))
		w.unit_defs[key] = def
		w.damage_profile[key] = w.damage_profile.get(BASE[key], {}).duplicate()
		var list: Array = w.building_defs[HOME[key]].trains
		if not key in list: list.append(key)
	w.damage_profile.type45 = {"air": 3.0, "naval": 1.0, "building": 0.35, "light": 0.5, "armor": 0.35, "infantry": 0.5}
	w.damage_profile.superTucano = {"air": 0.0, "naval": 0.3, "building": 0.7, "light": 1.5, "armor": 0.4, "infantry": 1.5}
	w.damage_profile.interceptorDrone = {"air": 2.0}
	w.damage_profile.kcr60.naval = float(w.damage_profile.kcr60.get("naval", 1.0)) * 1.25
	w.damage_profile.bushmaster.armor = 0.1
	w.damage_profile.ctsGolden.building = float(w.damage_profile.ctsGolden.get("building", 1.0)) * 1.4
	# The squad is the charge: one blast (world.fire_weapon "detonate"). A Taliban suicide attack killed 4.4
	# people on average (1982-2015) where an attack by other means killed 1.14: 3.9 times as many. So one blast
	# is 3.9 of the strongest single infantry attack, a rocket team's shot (armour takes 0.6 of it).
	w.unit_defs.suicideSquad.dmg = float(w.unit_defs.rocketSoldier.dmg) * SQUAD_FACTOR
	w.unit_defs.suicideSquad.aggro = 22.0
	w.damage_profile.suicideSquad = {"infantry": 1.0, "light": 1.0, "armor": 0.6, "air": 0.0, "naval": 0.5, "building": 1.2}
	if id_of(w, 0) == "egypt":
		w.unit_defs.worker.name = "Engineering Corps"
		w.unit_defs.worker.desc = "Egyptian engineers: build and repair 25% faster. Retain standard worker mining duties."
	# Player building cards and charges share the same discounted cost. AI uses building_cost().
	for key in profile(w, 0).get("build_costs", {}):
		w.building_defs[key].base_cost = w.building_defs[key].cost.duplicate()
		w.building_defs[key].cost = building_cost(w, 0, key, w.building_defs[key].cost)
static func ai_unlocked(w: Node, owner: int, key: String) -> bool:
	if not UNITS.has(key): return true
	var need: String = UNITS[key].requires
	return w.research != null and w.research.ai_tech(owner) >= float(w.research.era_of(need)) * 2.0
static func building_cost(w: Node, owner: int, key: String, cost: Dictionary) -> Dictionary:
	var result := cost.duplicate()
	var mult: float = float(profile(w, owner).get("build_costs", {}).get(key, 1.0))
	for r in result: result[r] = ceilf(float(result[r]) * mult)
	return result
static func train_mult(w: Node, owner: int, key: String) -> float:
	var group := "drone" if base(key) in ["drone", "loiterer", "fpvTeam"] else ("infantry" if key in w.infantry_keys and key != "worker" else "")
	return float(profile(w, owner).get("train", {}).get(group, 1.0))
static func road_mult(w: Node, owner: int, repair: bool) -> float:
	var p := profile(w, owner)
	return float(p.get("road_cost", 1.0)) * (float(p.get("repair_cost", 1.0)) if repair else 1.0)
static func building_health(w: Node, owner: int, key: String) -> float:
	return 1.25 if id_of(w, owner) == "north_korea" and key == "bunker" else 1.0
static func construction_mult(w: Node, owner: int) -> float:
	return 1.25 if id_of(w, owner) == "egypt" else 1.0
static func explosive_armor(key: String, source: String) -> float:
	return 0.75 if key == "bushmaster" and base(source) in ["artillery", "mlrs", "himars", "jet", "bomber", "drone", "loiterer", "rocketSoldier", "atgmTeam", "fpvTeam", "tos1a", "brahmos", "shahed", "missile", "gunship", "helicopter", "harop", "akinci"] else 1.0
