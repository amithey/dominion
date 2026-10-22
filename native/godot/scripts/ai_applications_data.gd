extends RefCounted
## Evidence and balancing are separate: priorities are scenario design, never a claim of secret capabilities.
## Sources and uncertainty: native/AI-APPLICATIONS-RESEARCH-2026-10-11.md.
const COUNTRY := {
	"usa": ["Operational programmes", "Maven decision support; autonomous-system procurement; industrial and public-sector AI.", ["sensors", "logistics", "cyber", "science"]],
	"china": ["National adoption programme", "AI+ prioritises industry and public services; precise military deployment remains opaque.", ["industry", "administration", "sensors", "science"]],
	"uk": ["Defence adoption strategy", "Defence AI strategy and public-sector experimentation; procurement does not prove universal fielding.", ["assurance", "cyber", "diplomacy", "science"]],
	"israel": ["Applied AI and national investment", "Strong applied AI ecosystem and national infrastructure investment; targeting claims require independent scrutiny.", ["sensors", "cyber", "autonomy", "science"]],
	"russia": ["Applied models; opaque military use", "Domestic financial-sector AI is documented; battlefield autonomy claims have uneven independent verification.", ["autonomy", "cyber", "industry", "logistics"]],
	"ukraine": ["Fielded systems and trials", "Defence Ministry reports deployed vision systems and Brave1 trials; performance remains environment-dependent.", ["autonomy", "sensors", "logistics", "cyber"]],
	"india": ["Funded mission and applied centres", "IndiaAI offers shared compute; agriculture, health and public services are named application areas.", ["agriculture", "administration", "health", "science"]],
	"japan": ["Government rollout and industrial AI", "Government AI platform and procurement guidance; human review and data preparation accompany adoption.", ["administration", "industry", "assurance", "health"]],
	"south_korea": ["Sovereign-model development", "National model competition and economic AI transformation; industrial strength does not imply unrestricted military autonomy.", ["industry", "science", "cyber", "administration"]],
	"turkiye": ["Manufacturer-reported autonomy", "STM describes vision, navigation and autonomous systems; supplier claims are not independent combat validation.", ["autonomy", "sensors", "logistics", "industry"]],
	"australia": ["Defence trials and integration", "Ghost Bat and Ghost Shark programmes support autonomy development; trials are distinct from general deployment.", ["sensors", "autonomy", "assurance", "diplomacy"]],
	"saudi": ["National strategy and investment", "SDAIA prioritises data, infrastructure and services; investment plans are not evidence of frontier capability.", ["industry", "administration", "diplomacy", "health"]],
	"brazil": ["Funded national plan", "PBIA emphasises public services, skills, infrastructure and productive-sector adoption.", ["agriculture", "administration", "health", "industry"]],
	"indonesia": ["Roadmap and adoption", "National roadmap and responsible adoption agenda; advanced military deployment is not established here.", ["administration", "agriculture", "industry", "diplomacy"]],
	"egypt": ["National strategy", "National AI strategy supports applied development; strategy targets are not deployed national systems.", ["agriculture", "administration", "industry", "diplomacy"]],
	"pakistan": ["Approved policy; capacity building", "AI policy supports skills and adoption; power, access and deployment evidence limit advanced programmes.", ["agriculture", "administration", "cyber", "health"]],
	"iran": ["Research; uncertain deployment", "AI research exists; sanctions and limited public evidence constrain claims of advanced military deployment.", ["cyber", "industry", "agriculture", "health"]],
	"north_korea": ["Research; opaque deployment", "Published research and official claims do not establish the scale or reliability of deployed military AI.", ["cyber", "industry", "logistics", "agriculture"]],
	"iraq": ["Limited public evidence", "Applied pilots are plausible; no independently established national military AI programme is assumed.", ["administration", "agriculture", "health", "diplomacy"]],
	"syria": ["Reconstruction scenario", "No verified advanced national AI deployment used in this model; rebuild services and data first.", ["administration", "health", "agriculture", "diplomacy"]],
	"yemen": ["Reconstruction scenario", "Digital-development needs are documented; no operational national military AI is established here.", ["administration", "health", "agriculture", "diplomacy"]],
	"houthis": ["Unverified advanced AI claims", "Missiles and drones do not by themselves prove AI; advanced autonomous targeting is not assumed.", ["logistics", "administration", "agriculture", "cyber"]],
	"ethiopia": ["Institutions and applied development", "AI institute, policy and strategy are documented; application development is distinct from nationwide fielding.", ["agriculture", "administration", "health", "industry"]],
	"nigeria": ["National strategy and ecosystem", "NCAIR and the national strategy support adoption; infrastructure and local data remain constraints.", ["administration", "agriculture", "cyber", "industry"]],
	"sudan": ["Reconstruction scenario", "Digital resilience and services are priorities; advanced national military AI is not established.", ["agriculture", "health", "administration", "diplomacy"]],
	"south_sudan": ["Basic digital capacity building", "Finance institutions receive ICT support; this is not evidence of a national advanced AI programme.", ["administration", "agriculture", "health", "diplomacy"]],
}

const SECOND_GENERATION := "aiSecondGeneration"
const GEN2 := 1.5 # the second generation's effect

## research cost, compute validation work, commissioning money, running compute/s, upkeep/s are balance values.
const PROGRAMS := {
	"administration": {"name": "Public-service AI", "level": 1, "pool": "economy", "facility": "school", "research": "aiPublicServices", "cost": 360, "work": 60.0, "money": 450.0, "demand": 0.12, "upkeep": 0.7, "fx": {"incomePct": 0.06, "happiness": 2.0}, "desc": "Review permits, budgets and service queues. Income +6%, happiness +2 at full coverage; appeals stay with officials."},
	"agriculture": {"name": "Crop and water forecasting", "level": 1, "pool": "economy", "facility": "farm", "research": "aiCropForecasts", "cost": 320, "work": 55.0, "money": 400.0, "demand": 0.10, "upkeep": 0.6, "fx": {"foodPct": 0.12}, "desc": "Forecast yields and irrigation demand using local observations. Food +12% at full coverage; no benefit without a working farm."},
	"industry": {"name": "Industrial digital twins", "level": 2, "pool": "economy", "facility": "powerPlant", "research": "aiIndustrialTwins", "cost": 600, "work": 100.0, "money": 850.0, "demand": 0.22, "upkeep": 1.2, "fx": {"prodPct": 0.10, "incomePct": 0.04}, "desc": "Model grid demand and factory maintenance. Production +10%, income +4% at full coverage."},
	"health": {"name": "Outbreak surveillance", "level": 1, "pool": "economy", "facility": "hospital", "research": "aiHealthSurveillance", "cost": 420, "work": 70.0, "money": 550.0, "demand": 0.14, "upkeep": 0.8, "fx": {"health": 5.0}, "desc": "Aggregate clinical signals for human review. Health +5 at full coverage; biological-risk work is surveillance and response."},
	"diplomacy": {"name": "Diplomatic analysis desk", "level": 1, "pool": "intel", "facility": "library", "research": "aiDiplomaticAnalysis", "cost": 400, "work": 65.0, "money": 600.0, "demand": 0.12, "upkeep": 0.8, "fx": {}, "desc": "Compare agreements, translate and prepare talks. Opens a costed diplomatic consultation; diplomats choose the policy."},
	"logistics": {"name": "Operational logistics", "level": 2, "pool": "military", "facility": "barracks", "research": "aiOperationalLogistics", "cost": 650, "work": 110.0, "money": 900.0, "demand": 0.20, "upkeep": 1.1, "fx": {"trainPct": 0.10}, "desc": "Schedule maintenance and training capacity. Training +10% at full coverage; no extra weapons or free supplies."},
	"sensors": {"name": "Multisensor intelligence", "level": 3, "pool": "intel", "facility": "fusionCell", "research": "aiSensorIntegration", "cost": 850, "work": 150.0, "money": 1200.0, "demand": 0.28, "upkeep": 1.5, "fx": {}, "desc": "Correlate existing observations. Intelligence analysis +20%, recon persistence +12%; does not reveal unseen enemies."},
	"autonomy": {"name": "Resilient drone integration", "level": 3, "pool": "military", "facility": "fusionCell", "research": "aiResilientAutonomy", "cost": 900, "work": 160.0, "money": 1300.0, "demand": 0.30, "upkeep": 1.6, "fx": {}, "desc": "Validate drone software in degraded conditions. Drone damage up to +6%, jamming risk up to 10% lower; never immunity."},
	"cyber": {"name": "Defensive AI operations", "level": 2, "pool": "intel", "facility": "techPark", "research": "aiDefensiveOperations", "cost": 650, "work": 110.0, "money": 950.0, "demand": 0.22, "upkeep": 1.2, "fx": {}, "desc": "Triage intrusions and isolate compromised services. Cyber defence +12 percentage points at full coverage."},
	"assurance": {"name": "Model evaluation and audit", "level": 2, "pool": "intel", "facility": "university", "research": "aiModelEvaluation", "cost": 700, "work": 120.0, "money": 1000.0, "demand": 0.20, "upkeep": 1.2, "fx": {}, "desc": "Independent tests, operator training and model audits. Autonomous-incident and AGI-runaway rates up to 25% lower; never zero."},
	"strategic": {"name": "Strategic warning verification", "level": 3, "pool": "intel", "facility": "fusionCell", "research": "aiStrategicVerification", "cost": 1100, "work": 190.0, "money": 1700.0, "demand": 0.35, "upkeep": 2.0, "fx": {}, "desc": "An independent review channel checks nuclear-warning alerts. False-alarm rate up to 40% lower; human release authority remains. Nuclear powers only."},
	"science": {"name": "Validated research automation", "level": 4, "pool": "economy", "facility": "university", "research": "aiResearchAutomation", "cost": 1300, "work": 240.0, "money": 2000.0, "demand": 0.40, "upkeep": 2.4, "fx": {"researchPct": 0.15}, "desc": "Automate literature review and reproducibility checks. Research +15% at full coverage; frontier capability required."},
	# The strategic applications: who uses them, and the record behind each, in ai_use_data.gd.
	"revenue": {"name": "Tax and fraud analytics", "level": 1, "pool": "economy", "facility": "bank", "research": "aiRevenueAnalytics", "cost": 380, "work": 60.0, "money": 500.0, "demand": 0.12, "upkeep": 0.7, "fx": {"incomePct": 0.05}, "desc": "Match returns, invoices and customs records to find evasion and fraud. Income +5% at full coverage; inspectors still decide each case."},
	"targeting": {"name": "Targeting decision support", "level": 3, "pool": "military", "facility": "fusionCell", "research": "aiTargetingSupport", "cost": 900, "work": 150.0, "money": 1300.0, "demand": 0.28, "upkeep": 1.5, "fx": {}, "desc": "Turn sensor feeds into ranked target lists faster than staff can. Artillery, rockets and strike aircraft +8% damage at full coverage. Speed outruns review: civilian buildings are sometimes struck even with a human approving, more often without one."},
	"counterDrone": {"name": "Counter-drone battle management", "level": 2, "pool": "military", "facility": "samSite", "research": "aiCounterDrone", "cost": 600, "work": 100.0, "money": 850.0, "demand": 0.20, "upkeep": 1.1, "fx": {"interceptPct": 0.06}, "desc": "Acoustic, radar and camera feeds classify small drones and assign the cheapest interceptor. Interception +6% at full coverage."},
	"undersea": {"name": "Undersea sensing", "level": 3, "pool": "intel", "facility": "shipyard", "research": "aiUnderseaSensing", "cost": 950, "work": 160.0, "money": 1400.0, "demand": 0.30, "upkeep": 1.6, "fx": {}, "desc": "Sonar processing and uncrewed sensor vessels. Your weapons hit submarines +20% harder at full coverage, and a nuclear rival's second strike is less certain. While you hunt a nuclear power's submarines in war, nuclear tension rises."},
	"surveillance": {"name": "Mass surveillance", "level": 2, "pool": "intel", "facility": "policeStation", "research": "aiMassSurveillance", "cost": 550, "work": 90.0, "money": 800.0, "demand": 0.20, "upkeep": 1.0, "fx": {"happiness": -3.0}, "desc": "Cameras with face recognition, phone and payment data. Enemy agents are caught more often and war-weariness turns into protest a third less; happiness -3, and democracies think less of you. Barred by law in the EU."},
	"infoShield": {"name": "Counter-disinformation", "level": 2, "pool": "intel", "facility": "tvStation", "research": "aiInfoShield", "cost": 500, "work": 85.0, "money": 700.0, "demand": 0.16, "upkeep": 0.9, "fx": {}, "desc": "Detect synthetic media and coordinated fake accounts and expose them. Rival influence campaigns succeed less often and do half the harm at full coverage."},
	"export": {"name": "AI exports", "level": 3, "pool": "economy", "facility": "aiDataCenter", "research": "aiExports", "cost": 800, "work": 130.0, "money": 1200.0, "demand": 0.24, "upkeep": 1.2, "fx": {}, "desc": "Package compute, models and services for other governments. Opens sales to nations at peace with you: money, relations +10, and access to the buyer's networks."},
	"deadHand": {"name": "Automated retaliation", "level": 2, "pool": "military", "facility": "missileSilo", "research": "aiAutomatedRetaliation", "cost": 1000, "work": 160.0, "money": 1600.0, "demand": 0.25, "upkeep": 1.8, "fx": {}, "desc": "A machine that answers a nuclear attack with your stored warheads even if no one is left to order it. Rivals are half as likely to use nuclear weapons on you. A false warning may fire it. Nuclear powers not bound by the declaration on human control."},
	"biosecurity": {"name": "Biosecurity screening", "level": 2, "pool": "economy", "facility": "hospital", "research": "aiBiosecurity", "cost": 500, "work": 85.0, "money": 750.0, "demand": 0.15, "upkeep": 0.8, "fx": {"health": 2.0}, "desc": "Screen DNA-synthesis orders and watch for unusual outbreaks. Epidemics spread far less between your towns, an unrestricted model's pathogen does less harm, health +2."},
}

## [headline, evidence, application priorities] for nation `id`: the table above, then the
## "ai_evidence" of its own file, then an honest "limited evidence".
static func evidence(id: String) -> Array:
	if COUNTRY.has(id): return COUNTRY[id]
	return preload("res://scripts/nation_registry.gd").data(id).get("ai_evidence", ["Limited evidence", "No verified deployment assumed.", []])

static func has_evidence(id: String) -> bool:
	return COUNTRY.has(id) or preload("res://scripts/nation_registry.gd").data(id).has("ai_evidence")

static func discoveries() -> Dictionary:
	var out := {}
	for key in PROGRAMS:
		var p: Dictionary = PROGRAMS[key]
		out[p.research] = {"name": p.name, "cost": p.cost, "branch": "hightech", "era": 3 if int(p.level) <= 2 else (4 if int(p.level) == 3 else 5), "reqDiscovery": "machineLearning" if int(p.level) <= 2 else ("militaryAI" if int(p.level) == 3 else "frontierModels"), "reqBuilding": p.facility, "fx": {}, "desc": p.desc + " Complete this discovery, then validate and commission it in Defence > AI > Applications."}
	out[SECOND_GENERATION] = {"name": "Fielded AI: the second generation", "cost": 900, "branch": "hightech", "era": 4, "reqDiscovery": "machineLearning", "reqBuilding": "university", "fx": {},
		"desc": "Systems in service collect the data that trains their successors. An application that has run long enough (its field experience is full) can be upgraded in Defence > AI > Applications: its effect is half again as strong."}
	return out

static func needs(key: String) -> int:
	if key == SECOND_GENERATION: return 2
	for p in PROGRAMS.values():
		if p.research == key: return int(p.level)
	return 0
