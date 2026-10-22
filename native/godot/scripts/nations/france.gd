extends RefCounted
## France. Registered in nation_registry.gd; its position there is its saved index.
## Taken from the European Union's rows as the union is split into its members:
## native/EU-SPLIT-LEDGER.md lists what each row became.
const DATA := {
	"id": "france",
	"group": "expansion",
	"arsenal": "france",
	"name": "France",
	"leader": "President Emmanuel Macron",
	"colour": "#2b4aa8",
	"portrait": "macron",
	"signature": "Charles de Gaulle",
	"doctrine": "Independence and reach: a permanent seat and veto at the Security Council, a carrier group, and air defence 10% cheaper. A smaller army than its neighbours and a thin domestic energy supply: oil and gas output are halved, and public debt weighs on politics.",
	# Income: GDP a head near $49,000 puts it in the tier of the United Kingdom (+10%). Research +5%, the
	# lower half of that tier: its output of scientific articles a million people is below the British
	# (not re-checked this round, see the ledger). Oil and gas: almost none is produced at home, and the
	# game has no nuclear power to credit. Growth 0.9: below-replacement births, above the Union's average.
	# Happiness -2: governments have fallen in quick succession and the public debt is high.
	"profile": {"bonus": {"incomePct": 0.10, "researchPct": 0.05, "happiness": -2.0}, "growth": 0.9, "resources": {"oil": 0.5, "gas": 0.5}, "costs": {"airDefence": 0.9},
		"strengths": ["Income +10%, research +5%", "A permanent seat and veto at the Security Council", "Air defence 10% cheaper (SAMP/T)", "The Charles de Gaulle carrier group"],
		"weaknesses": ["Almost no oil or gas of its own: output -50%", "Fragile politics and a high public debt: -2 happiness", "Population grows 10% slower"]},
	"ai": {"compute": 2, "models": 4, "autonomy": 2, "cyber": 4, "lean": "in", "signs": ["nuclear"], "ceiling": 4,
		"why": "A leading European model laboratory and a national supercomputer, but little frontier compute."},
	"ai_evidence": ["Defence AI agency and a national laboratory", "A ministry agency for defence AI sets standards, and the armed forces hold a framework agreement with a domestic model supplier; fielding beyond trials is not public.", ["sensors", "cyber", "assurance", "industry"]],
	"ai_use": {
		"targeting": ["developing", "The armed forces' Artemis.IA platform processes intelligence data at scale; its use in targeting is not public."],
		"undersea": ["developing", "The seabed strategy funds underwater drones and sensor networks to protect cables and pipelines."],
		"surveillance": ["fielded", "Algorithmic video analysis, without facial recognition, was authorised by law for the Olympic Games and later extended."],
		"infoShield": ["fielded", "VIGINUM, a state agency, detects and attributes foreign digital interference."],
		"revenue": ["fielded", "The tax administration mines data to find undeclared income and property."],
		"deadHand": ["pledged", "France, a nuclear power, has committed to human control of nuclear decisions."]},
	"dossier": {
		"profile": {"land": "Leclerc tanks, VBCI infantry vehicles and CAESAR wheeled guns suit a compact expeditionary army; stock counts are not modelled.", "air": "Rafale is the main combat aircraft, with Mirage 2000 variants in ground attack and as a light fighter, and E-3F aircraft for airborne warning.", "sea": "Charles de Gaulle is the only carrier and cannot be everywhere; FREMM frigates, Mistral-class ships and Atlantique 2 patrol aircraft support it.", "fires": "SAMP/T NG and Aster missiles give layered air defence; CAESAR guns and the COBRA counter-battery radar support the artillery, whose stocks are limited.", "support": "Overseas bases and a long expeditionary tradition support deployment, but ammunition and spares are the central uncertainty in a long, high-intensity war.", "limits": "Public sources show the types in service, not stocks, readiness or how many ships and aircraft can deploy at once; the size of the nuclear arsenal is an estimate, not a count.", "watch": ["The carrier's successor programme and the Rafale upgrade path: timing remains uncertain"], "sources": ["france", "sipri"]},
		"sources": {},
		"roster": {
			"wheeledHowitzer": ["CAESAR", "france", "Delivered French equipment"],
		},
	},
	"force_names": {
		"carrier": "Charles de Gaulle",
		"aewc": "E-3F Sentry",
		"maritimePatrol": "Atlantique 2",
		"asFrigate": "FREMM",
		"landingShip": "Mistral-class",
		"attackJet": "Mirage 2000D",
		"lightFighter": "Mirage 2000-5F",
		"navalHelicopter": "NH90 NFH",
		"counterBatteryRadar": "COBRA",
		"ifv": "VBCI",
		"reconVehicle": "EBRC Jaguar",
	},
	"capabilities": {
		"units": ["sixthGen", "nuclearSub", "destroyer", "laserAD", "abmLauncher"],
		"not_units": ["submarine"],   # her submarines are all nuclear: the Triomphant and Suffren classes
		"research": ["sixthGeneration", "nuclearProgram", "directedEnergy", "missileDefence"],
		"missiles": ["nuke"],
		"names": {
			"tank": "Leclerc XLR", "apc": "Griffon", "artillery": "CAESAR", "mlrs": "LRU", "aaVehicle": "Crotale NG", "corvette": "La Fayette-class", "samLauncher": "SAMP/T NG",
			"helicopter": "NH90 Caiman", "gunship": "Tiger", "jet": "Rafale", "drone": "MQ-9 Reaper", "destroyer": "Horizon-class",
			"nuclearSub": "Triomphant-class", "atgmTeam": "MMP team", "manpads": "Mistral 3 team", "laserAD": "HELMA-P",
			"abmLauncher": "SAMP/T NG (Aster 30 B1NT)", "sixthGen": "SCAF / FCAS programme",
		},
	},
	"power": {"name": "Forward Deterrence", "target": true, "hostile": false, "cooldown": 600.0, "duration": 900.0, "costs": {"money": 600}, "needs": ["strategicComplex"],
		"desc": "$600: nuclear-capable aircraft are stationed on a partner's soil and it joins the exercises, for 15 minutes. Rivals will not start a war with it; Paris keeps command and the partner gets no warhead. Relations with the partner rise 10; nations hostile to it think less of France. A war already begun goes on. Needs a partner at peace (+20 relations or better) and a supplied Strategic Weapons Complex."},
}
