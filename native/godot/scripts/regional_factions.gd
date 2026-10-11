extends RefCounted
## Sources and scenario limits: docs/planning/SEVEN-ENTITIES-GAME-PROFILES-2026-10-10.md.
## Values below are game balance, not factual measures of national readiness.
## Append-only identities preserve the original 22 selection indices and saved arsenals.
const IDS := ["yemen", "houthis", "ethiopia", "nigeria", "sudan", "south_sudan"]
const NAMES := ["Yemen (Recognized Government)", "Houthis (Ansar Allah)", "Ethiopia", "Nigeria", "Sudan", "South Sudan"]
const LEADERS := ["Presidential Leadership Council", "Ansar Allah Leadership", "Federal Government of Ethiopia", "Federal Government of Nigeria", "Sudanese Authorities", "Government of South Sudan"]
const COLOURS := ["#ba6557", "#748653", "#66a465", "#31967b", "#b39160", "#6285b3"]
const PORTRAITS := ["yemen", "houthis", "ethiopia", "nigeria", "sudan", "south-sudan"]
const SIGNATURES := ["Reconstruction Crew", "Coastal Drone Battery", "Hydropower Grid", "A-29 / JF-17", "Reconstruction Engineers", "Oil Transit Contract"]
const DOCTRINES := [
	"Rebuild institutions: affordable civilian construction and partner-funded reconstruction. Limited ground forces; no assumed operational fighter fleet. Competes with Ansar Allah within Yemen.",
	"Ansar Allah: an armed authority within Yemen, with drones and coastal pressure. A coastal battery can briefly disrupt an enemy's shipping; escorts reduce the effect. No separate UN seat or fighter fleet.",
	"Hydropower and corridors: agricultural output supports a growing population. A supplied power plant can sell a timed grid contract to a friendly partner. Landlocked: no ports or navy.",
	"Energy and industry: strong oil and gas output, but an unreliable grid slows production. Pay to stabilize a supplied power plant. A-29 ground support and JF-17 fighters require research.",
	"Reconstruction: agriculture and engineering support recovery from war damage. Pay to repair damaged buildings near the capital. Sudan is distinct from South Sudan; the skirmish does not reproduce territorial control in the civil war.",
	"Oil and transit: export actual oil stocks through a paid agreement with Sudan. Both sides need supplied extractors; war or lost infrastructure cancels the escrow and refunds it. Landlocked, with a limited ground roster."
]
const PROFILES := {
	"yemen": {"bonus": {"incomePct": -0.2, "researchPct": -0.2}, "trade": 0.85, "build_costs": {"farm": 0.85, "school": 0.85, "villageCenter": 0.85}, "strengths": ["Farms, schools and village centres cost -15%", "Partner-funded reconstruction; workers build 15% faster"], "weaknesses": ["Income and research -20%, trade -15%", "No fighters, strategic weapons or advanced navy"]},
	"houthis": {"bonus": {"incomePct": -0.25, "researchPct": -0.25}, "trade": 0.7, "unit_costs": {"loiterer": 0.8, "fpvTeam": 0.85}, "strengths": ["Loitering munitions cost -20%, FPV teams -15%", "Limited coastal shipping pressure"], "weaknesses": ["Income and research -25%, trade -30%", "No fighters, advanced navy or separate UN seat"]},
	"ethiopia": {"bonus": {"incomePct": -0.15, "researchPct": -0.15, "foodPct": 0.15}, "growth": 1.1, "strengths": ["Farm output +15%, population growth +10%", "Paid hydropower export contracts"], "weaknesses": ["Income and research -15%", "Landlocked: no ports or navy"]},
	"nigeria": {"bonus": {"incomePct": -0.1, "researchPct": -0.1, "prodPct": -0.1}, "resources": {"oil": 1.4, "gas": 1.3}, "strengths": ["Oil output +40%, gas +30%", "Researchable A-29 and JF-17; paid grid stabilization"], "weaknesses": ["Income, research and production -10%", "No submarines, strategic missiles or nuclear weapons"]},
	"sudan": {"bonus": {"incomePct": -0.2, "researchPct": -0.2, "foodPct": 0.1}, "repair_cost": 0.75, "strengths": ["Farm output +10%, road repair costs -25%", "Paid reconstruction near the capital; oil transit partner"], "weaknesses": ["Income and research -20%", "War recovery; no strategic weapons or advanced navy"]},
	"south_sudan": {"bonus": {"incomePct": -0.25, "researchPct": -0.25, "prodPct": -0.15}, "resources": {"oil": 1.5}, "strengths": ["Oil output +50%", "Paid oil exports through Sudan"], "weaknesses": ["Income and research -25%, production -15%", "Landlocked; limited arms access and dependence on transit"]}
}
const COMMON := ["worker", "soldier", "rocketSoldier", "machineGunTeam", "mortarTeam", "scoutTeam", "medic", "sniper", "commando", "atgmTeam", "manpads", "tank", "apc", "artillery", "aaVehicle", "transport"]
const EQUIPMENT := {
	"yemen": ["gunboat", "fpvTeam"],
	"houthis": ["gunboat", "fpvTeam", "loiterer", "mlrs", "coastalDrone"],
	"ethiopia": ["helicopter", "jet", "drone", "akinci", "fpvTeam", "mlrs", "samLauncher"],
	"nigeria": ["helicopter", "jet", "superTucano", "jf17", "gunship", "drone", "gunboat", "corvette", "fpvTeam"],
	"sudan": ["helicopter", "jet", "gunship", "drone", "fpvTeam", "mlrs", "gunboat"],
	"south_sudan": []
}
const DISCOVERIES := {
	"egyptWaterWorks": {"name": "Nile Water Management", "nation": "egypt", "branch": "economy", "era": 2, "cost": 450, "reqDiscovery": null, "reqBuilding": "farm", "fx": {"foodPct": 0.15}, "desc": "Improve irrigation efficiency: farm output +15%."},
	"yemenInstitutions": {"name": "Rebuild Civil Institutions", "nation": "yemen", "branch": "economy", "era": 2, "cost": 350, "reqDiscovery": null, "reqBuilding": "school", "fx": {"researchPct": 0.1}, "desc": "Restore education and administration: research +10%."},
	"houthiSupply": {"name": "Dispersed Drone Workshops", "nation": "houthis", "branch": "army", "era": 2, "cost": 400, "reqDiscovery": null, "reqBuilding": "barracks", "fx": {"prodPct": 0.1}, "desc": "Disperse workshops and spare parts: production +10%."},
	"ethiopiaGrid": {"name": "Hydropower Distribution", "nation": "ethiopia", "branch": "economy", "era": 2, "cost": 450, "reqDiscovery": null, "reqBuilding": "powerPlant", "fx": {"prodPct": 0.15}, "desc": "Connect hydropower to industry: production +15%."},
	"nigeriaGasGrid": {"name": "Gas to Power", "nation": "nigeria", "branch": "economy", "era": 2, "cost": 450, "reqDiscovery": null, "reqBuilding": "powerPlant", "fx": {"prodPct": 0.1}, "desc": "Improve gas supply to generation: production +10%."},
	"sudanRecovery": {"name": "Agricultural Recovery", "nation": "sudan", "branch": "economy", "era": 2, "cost": 350, "reqDiscovery": null, "reqBuilding": "farm", "fx": {"foodPct": 0.15}, "desc": "Restore irrigation and farm access: farm output +15%."},
	"southSudanInstitutions": {"name": "Revenue Administration", "nation": "south_sudan", "branch": "economy", "era": 2, "cost": 350, "reqDiscovery": null, "reqBuilding": "school", "fx": {"incomePct": 0.1}, "desc": "Improve public revenue administration: income +10%."}
}
const AI_PROFILES := {
	"yemen": {"compute": 0, "models": 0, "autonomy": 1, "cyber": 0, "lean": "in", "signs": [], "ceiling": 1, "why": "Reconstruction and unreliable power constrain domestic compute; imported applied tools only."},
	"houthis": {"compute": 0, "models": 0, "autonomy": 1, "cyber": 1, "lean": "in", "signs": [], "ceiling": 1, "why": "Drone guidance is not a domestic advanced AI industry; electronics remain constrained."},
	"ethiopia": {"compute": 0, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in", "signs": [], "ceiling": 2, "why": "Applied AI development with limited domestic compute and access to advanced chips."},
	"nigeria": {"compute": 0, "models": 1, "autonomy": 1, "cyber": 1, "lean": "in", "signs": [], "ceiling": 2, "why": "An applied technology sector, constrained by power reliability and imported compute."},
	"sudan": {"compute": 0, "models": 0, "autonomy": 1, "cyber": 0, "lean": "in", "signs": [], "ceiling": 1, "why": "War damage and infrastructure recovery limit domestic computing capacity."},
	"south_sudan": {"compute": 0, "models": 0, "autonomy": 0, "cyber": 0, "lean": "in", "signs": [], "ceiling": 1, "why": "Limited power and connectivity; basic imported software precedes advanced AI."}
}
static func fields(id: String, key: String) -> bool:
	return key in COMMON or key in EQUIPMENT.get(id, [])
static func builds(id: String, key: String) -> bool:
	if key in ["silo", "missileSilo", "nuclearReactor", "strategicComplex", "specialLab"]: return false
	if id in ["ethiopia", "south_sudan"] and key in ["port", "shipyard"]: return false
	return true
static func metadata(id: String) -> Dictionary:
	if not id in IDS: return {}
	return {"un": "none" if id == "houthis" else "member", "un_region": "Asia-Pacific" if id in ["yemen", "houthis"] else "Africa", "nam": id != "houthis", "ai_profile": AI_PROFILES[id].duplicate(true)}

static func apply(w: Node) -> void:
	for key in DISCOVERIES: w.map.research.discoveries[key] = DISCOVERIES[key].duplicate(true)
	# Shared operators, not national exclusivity: Nigeria fields both imported types.
	for key in ["superTucano", "jf17"]:
		w.unit_defs[key].nation = ["brazil" if key == "superTucano" else "pakistan", "nigeria"]
		w.unit_defs[key].desc = "A-29 ground support; cannot fight jets." if key == "superTucano" else "JF-17 multirole fighter; 15% less health, trains 20% faster."
	var def: Dictionary = w.unit_defs.fpvTeam.duplicate(true)
	def.merge({"nation": "houthis", "name": "Coastal Drone Battery", "requires": "microchips", "desc": "Ansar Allah coastal drone launcher. Requires imported electronics; fragile against aircraft."}, true)
	def.cost.silicon = 40
	w.unit_defs.coastalDrone = def
	if not "coastalDrone" in w.infantry_keys: w.infantry_keys.append("coastalDrone")
	w.damage_profile.coastalDrone = w.damage_profile.get("fpvTeam", {}).duplicate(true)
	if not "coastalDrone" in w.building_defs.barracks.trains: w.building_defs.barracks.trains.append("coastalDrone")

static func restrict(w: Node, everyone: Array) -> void:
	for key in w.unit_defs:
		var allowed := []
		var field = w.unit_defs[key].get("nation", "")
		for id in everyone:
			if id in IDS:
				if fields(id, key): allowed.append(id)
			elif (field is Array and id in field) or (not field is Array and (str(field) == "" or str(field) == id)):
				allowed.append(id)
		# Retain legacy single-nation fields and their existing interface messages.
		if str(field) == "" or allowed.any(func(id): return id in IDS):
			w.unit_defs[key].nation = allowed
	for key in w.map.research.discoveries:
		if key in DISCOVERIES: continue
		if key in ["nuclearProgram", "stealthTech", "navalEngineering", "aiRevolution"]:
			var d: Dictionary = w.map.research.discoveries[key]
			var field = d.get("nation", "")
			d.nation = everyone.filter(func(id): return not id in IDS and ((field is Array and id in field) or (not field is Array and (str(field) == "" or str(field) == id))))
	for key in w.map.missiles.get("types", {}):
		var m: Dictionary = w.map.missiles.types[key]
		var field = m.get("nation", "")
		m.nation = everyone.filter(func(id): return not id in IDS and ((field is Array and id in field) or (not field is Array and (str(field) == "" or str(field) == id))))
